class MixerDefine {
  final String name;
  final int? index;
  final List<MixerDefine> children;
  int itemValue;
  
  /*
    -1 - unknown
    0 - vertical slider
    1 - radio button
    2 - switch button
  */
  int displayType;

  MixerDefine({
    required this.name,
    this.index,
    this.children = const [],
    this.itemValue = 0,
    this.displayType = -1,
  });

  @override
  String toString() {
    return 'MixerDefine(name: $name, index: $index, value: $itemValue, type: $displayType, children: ${children.length})';
  }
  
  void debugPrintTree([String prefix = '']) {
    // Determine the display string for the current node
    String display = name;
    if (index != null) {
      display += ' ($index)';
    }
    if (displayType != -1) {
      display += ' | Display Type : $displayType';
    }
    if (itemValue != 0) {
      display += ' | Value : $itemValue';
    }
    
    print('$prefix$display');
    
    // Recursively print children
    for (var child in children) {
      child.debugPrintTree('$prefix  ');
    }
  }
}
