from PIL import Image
import os

def resize_icon(input_path, output_path, size=(512, 512)):
    if not os.path.exists(input_path):
        print(f"Input file {input_path} not found.")
        return
    
    img = Image.open(input_path)
    # Ensure it's in a compatible mode (RGBA to RGB if needed, but PNG is fine)
    img = img.convert("RGBA")
    img_resized = img.resize(size, Image.Resampling.LANCZOS)
    img_resized.save(output_path, "PNG", optimize=True)
    
    file_size = os.path.getsize(output_path) / 1024
    print(f"Generated {output_path}: {size[0]}x{size[1]}, {file_size:.2f} KB")

if __name__ == "__main__":
    resize_icon("assets/images/app_icon.png", "play_store_icon.png")
