# BLE Android Communication Format

## Problem Summary
Define a compact BLE protocol for MCU <-> Android data exchange with two payload types: Command (short) and Data (large, segmented). Commands include categories MIC, MUSIC, RECORD, SYSTEM, APP MODE. Provide an index/value mapping model for MIC volume and similar objects.

## Assumptions & Constraints
- BLE transport is write/notify with MTU constraints; payloads can be fragmented.
- Payloads are little-endian for multi-byte fields.
- Command payloads are short and fit in a single BLE packet.
- Data payloads may exceed a single packet and require segmentation and reassembly.
- MTU is 256 bytes for payload sizing.
- No encryption or authentication is specified in this draft.

## Architecture Overview (HAL / Driver / Service / App)
- HAL/Driver: BLE stack provides read/write/notify.
- Service: BLE app service (SC00) carries MCU <-> Android exchange.
- App: Protocol framing, parsing, and routing to command/data handlers.

## Task Model & RTOS Strategy
- Rx: BLE callback enqueues frames for parsing in a protocol task.
- Tx: Application task builds frames and sends via BLE API.
- Reassembly: Data frames buffered until complete (based on length and sequence).

## ISR Strategy
- No ISR direct processing; use task context for parsing and state updates.

## Data Flow & Control Flow
1) Receive BLE packet -> parse header -> route by type (Command/Data).
2) Command: dispatch by category and command ID, apply get/set.
3) Data: reassemble segments using message ID + sequence.
4) Responses: ACK/NAK or data reply with status codes.

## Error Handling Strategy
- Validate header, length, and CRC (if enabled).
- Reject unknown version/type/category with NAK.
- Drop incomplete data after timeout.

## Safety & Reliability Considerations
- Bounded buffers for reassembly; protect with mutex if shared.
- Avoid dynamic allocation; use static ring buffers or fixed slots.
- Enforce maximum payload lengths per MTU.

## Test Strategy
- Unit tests for frame parsing, command dispatch, and data reassembly.
- Fuzz invalid headers, invalid length, and out-of-order segments.

---

## Protocol Draft

### 1) Frame Header (Fixed 8 bytes)
All fields little-endian.

| Offset | Size | Field        | Description |
|-------:|-----:|--------------|-------------|
| 0      | 1    | Magic        | 0xAA (start marker) |
| 1      | 1    | Version      | Protocol version, start at 0x01 |
| 2      | 1    | Type         | 0x01=Command, 0x02=Data |
| 3      | 1    | Flags        | Bit0=ACK req, Bit1=ACK resp, Bit2=Error |
| 4      | 2    | Length       | Payload length (not including header) |
| 6      | 1    | MsgId        | Message ID for pairing request/response |
| 7      | 1    | Seq          | Segment sequence (0 for Command) |

CRC16 is required and appended at the end of the frame.
CRC16 algorithm: ISO/IEC 14443-3 Type A (CRC-A).
CRC coverage: Header + Payload, appended LSB then MSB.

### 2) Command Payload
Command frames are single-segment, short payloads.

Payload layout:

| Offset | Size | Field        | Description |
|-------:|-----:|--------------|-------------|
| 0      | 1    | Category     | 0x01=MIC, 0x02=MUSIC, 0x03=RECORD, 0x04=SYSTEM, 0x05=APP_MODE |
| 1      | 1    | CmdId        | Command ID within category |
| 2      | 1    | Op           | 0x00=GET, 0x01=SET, 0x02=EVENT |
| 3      | 1    | PayloadLen   | Length of command data |
| 4      | N    | Payload      | Command data (PayloadLen bytes) |

#### MIC Category (0x01)
Use index/value maps to simplify mapping between UI and DSP fields.

MIC CmdId assignments:
- CmdId 0x01: MIC volume
- CmdId 0x02: MIC effects volume
- CmdId 0x03: MIC echo effects properties (maps to EchoParam)
- CmdId 0x04: MIC reverb effects properties (maps to ReverbParam)
- CmdId 0x05: MIC reverb plate effects properties (maps to PlateReverbParam)
- CmdId 0x06: MIC EQ IN (up to 10 bands, each band uses FilterParams)
- CmdId 0x07: MIC EQ OUT (same format and mapping as MIC EQ IN)
- CmdId 0x08: MIC feedback cancel enable/disable

Example: MIC Volume Command (CmdId 0x01)
Payload: list of pairs {Index, Value}

Payload format:
| Offset | Size | Field    | Description |
|-------:|-----:|----------|-------------|
| 0      | 1    | Count    | Number of pairs |
| 1      | 2*Count | Pairs | Repeating {Index (1 byte), Value (1 byte)} |

Example pairs:
- {1: mic1_volume, 2: mic1_mute, 3: mic2_volume, 4: mic2_mute, 5: mic_master_volume}

MIC effects volume (CmdId 0x02) index mapping:
- 1: mic_bass_gain
- 2: mic_middle_gain
- 3: mic_treb_gain
- 4: mic_echo_gain
- 5: mic_echo_delay_gain
- 6: mic_reverb_gain
- 7: mic_bypass_gain
- 8: mic_wired_gain

MIC echo effects properties (CmdId 0x03) index mapping (EchoParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: fc
- 2: attenuation
- 3: delay
- 4: reserved
- 5: max_delay
- 6: high_quality_enable
- 7: dry
- 8: wet

EchoParam index access rules:
- GET: MCU reads EchoParam by index and returns value (int16).
- SET: MCU writes EchoParam by index with provided value (int16).
- Invalid index returns error status.

MIC reverb effects properties (CmdId 0x04) index mapping (ReverbParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: dry_scale
- 2: wet_scale
- 3: width_scale
- 4: roomsize_scale
- 5: damping_scale
- 6: mono

ReverbParam index access rules:
- GET: MCU reads ReverbParam by index and returns value (int16, mono is uint16).
- SET: MCU writes ReverbParam by index with provided value.
- Invalid index returns error status.

MIC reverb plate effects properties (CmdId 0x05) index mapping (PlateReverbParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: highcut_freq
- 2: modulation_en
- 3: predelay
- 4: diffusion
- 5: decay
- 6: damping
- 7: wetdrymix

PlateReverbParam index access rules:
- GET: MCU reads PlateReverbParam by index and returns value (int16).
- SET: MCU writes PlateReverbParam by index with provided value.
- Invalid index returns error status.

MIC EQ IN (CmdId 0x06) mapping (EQParam in `app_framework/audio_engine/audio_effect_api.h`):
- Up to 10 bands, each band is a FilterParams entry.
- Each update targets a flattened index/value pair.

FilterParams field index mapping:
- 1: enable (uint16)
- 2: type (int16)
- 3: f0 (uint16)
- 4: Q (int16, Q6.10)
- 5: gain (int16, Q8.8)

MIC EQ IN payload format (command payload):
| Offset | Size | Field        | Description |
|-------:|-----:|--------------|-------------|
| 0      | 1    | Count        | Number of entries |
| 1      | 3*Count | Entries   | Repeating {Index (1 byte), Value (1 byte LSB, 1 byte MSB)} |

Index mapping rule:
- 1..50 map to {band, field} with 10 bands and 5 fields per band.
- band = (Index - 1) / 5, field = (Index - 1) % 5.
- field order per band: 0=enable, 1=type, 2=f0, 3=Q, 4=gain.

MIC EQ IN index access rules:
- GET: MCU reads EQParam.eq_params[band] field per index and returns value (int16 or uint16 for enable/f0).
- SET: MCU writes EQParam.eq_params[band] field per index with provided value.
- Invalid index returns error status.

MIC feedback cancel (CmdId 0x08):
- Single field: enable (0=disable, 1=enable).
- Payload uses single index/value pair: Index=1, Value=0 or 1.

#### MUSIC Category (0x02)
CmdId assignments:
- CmdId 0x01: Music volume and gains
- CmdId 0x02: Music EQ IN (same format and mapping as MIC EQ IN)
- CmdId 0x03: Music EQ OUT (same format and mapping as MIC EQ IN)
- CmdId 0x04: Music boost bass (VBParam + enable)
- CmdId 0x05: Music exciter (ExciterParam + enable)

Music volume (CmdId 0x01) index mapping:
- 1: music_in_volume
- 2: music_in_mute
- 3: music_out_volume
- 4: music_out_mute
- 5: music_bass_gain
- 6: music_middle_gain
- 7: music_treb_gain

Music boost bass (CmdId 0x04) index mapping (VBParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: f_cut
- 2: intensity
- 3: enhanced
- 4: enable (0=disable, 1=enable)

Music exciter (CmdId 0x05) index mapping (ExciterParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: f_cut
- 2: dry
- 3: wet
- 4: enable (0=disable, 1=enable)

MUSIC command access rules:
- GET: MCU reads target field by index and returns value (int16, enable/mute fields are uint16).
- SET: MCU writes target field by index with provided value.
- Invalid index returns error status.

#### RECORD Category (0x03)
CmdId assignments:
- CmdId 0x01: Record volume
- CmdId 0x02: Record EQ (same format and mapping as MIC EQ IN)

Record volume (CmdId 0x01) index mapping:
- 1: record_in_volume
- 2: record_out_volume
- 3: record_mute

RECORD command access rules:
- GET: MCU reads target field by index and returns value (int16, mute is uint16).
- SET: MCU writes target field by index with provided value.
- Invalid index returns error status.

#### SYSTEM Category (0x04)
CmdId assignments:
- CmdId 0x01: System app mode
- CmdId 0x02: Master volume

System app mode (CmdId 0x01) index mapping:
- 1: app_mode (value 1=Bluetooth, 2=Line In, 3=Optical, 4=Sound Card, 5=HDMI, 6=USB)

Master volume (CmdId 0x02) index mapping:
- 1: dac_gain
- 2: dac_mute

SYSTEM command access rules:
- GET: MCU reads target field by index and returns value (int16, mute is uint16).
- SET: MCU writes target field by index with provided value.
- Invalid index returns error status.

#### GUITAR Category (0x05)
CmdId assignments:
- CmdId 0x01: Guitar volume
- CmdId 0x02: Guitar EQ (same format and mapping as MIC EQ IN)
- CmdId 0x03: Guitar pingpong (PingPongParam)
- CmdId 0x04: Guitar chorus (ChorusParam)
- CmdId 0x05: Guitar auto wah (AutoWahParam)

Guitar volume (CmdId 0x01) index mapping:
- 1: volume_gain
- 2: mute

Guitar pingpong (CmdId 0x03) index mapping (PingPongParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: attenuation
- 2: delay
- 3: high_quality_enable
- 4: wetdrymix
- 5: max_delay

Guitar chorus (CmdId 0x04) index mapping (ChorusParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: delay_length
- 2: mod_depth
- 3: mod_rate
- 4: feedback
- 5: dry
- 6: wet

Guitar auto wah (CmdId 0x05) index mapping (AutoWahParam in `app_framework/audio_engine/audio_effect_api.h`):
- 1: modulation_rate
- 2: min_frequency
- 3: max_frequency
- 4: depth
- 5: dry
- 6: wet

GUITAR command access rules:
- GET: MCU reads target field by index and returns value (int16, mute is uint16).
- SET: MCU writes target field by index with provided value.
- Invalid index returns error status.

### 3) Data Payload (Segmented)
Data frames may carry large binary content.

Payload layout:

| Offset | Size | Field        | Description |
|-------:|-----:|--------------|-------------|
| 0      | 2    | TotalLen     | Total data length across all segments |
| 2      | 1    | SegmentCount | Total number of segments |
| 3      | 1    | SegmentIndex | Current segment index (0-based) |
| 4      | N    | Data         | Segment data |

Reassembly key: {MsgId, TotalLen}. Seq in header should match SegmentIndex.
Segment sizing: total frame length must not exceed MTU 256 bytes, including header and CRC16.

### 4) ACK / Error Response
Use Flags:
- ACK response: Flags bit1 set.
- Error: Flags bit2 set, with payload containing error code.

ACK payload (optional):
| Offset | Size | Field      | Description |
|-------:|-----:|------------|-------------|
| 0      | 1    | Status     | 0x00=OK, other=error |
| 1      | 1    | Category   | Echoed from request |
| 2      | 1    | CmdId      | Echoed from request |

### 5) Versioning
- Version byte in header enables backward compatibility.
- Reject unknown versions with NAK (Flags bit2 set, Status=0x01).

---

## Open Questions
1) Confirm exact CmdId assignments for MIC/MUSIC/RECORD/SYSTEM/APP_MODE.
