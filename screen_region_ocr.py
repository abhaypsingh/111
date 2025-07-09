import os
import time
import hashlib
from PIL import Image
import pytesseract
import mss
import tkinter as tk

class RegionSelector:
    def __init__(self):
        self.start_x = None
        self.start_y = None
        self.cur_x = None
        self.cur_y = None
        self.rect = None

    def on_button_press(self, event):
        self.start_x = event.x
        self.start_y = event.y
        self.rect = self.canvas.create_rectangle(self.start_x, self.start_y, 1, 1, outline='red', width=2)

    def on_move_press(self, event):
        self.cur_x, self.cur_y = (event.x, event.y)
        self.canvas.coords(self.rect, self.start_x, self.start_y, self.cur_x, self.cur_y)

    def on_button_release(self, event):
        self.cur_x, self.cur_y = (event.x, event.y)
        self.master.quit()


def select_region():
    root = tk.Tk()
    root.attributes("-alpha", 0.3)
    root.attributes("-fullscreen", True)
    root.attributes("-topmost", True)
    canvas = tk.Canvas(root, cursor="cross")
    canvas.pack(fill="both", expand=True)
    selector = RegionSelector()
    selector.master = root
    selector.canvas = canvas
    canvas.bind("<ButtonPress-1>", selector.on_button_press)
    canvas.bind("<B1-Motion>", selector.on_move_press)
    canvas.bind("<ButtonRelease-1>", selector.on_button_release)
    root.mainloop()
    x1 = min(selector.start_x, selector.cur_x)
    y1 = min(selector.start_y, selector.cur_y)
    x2 = max(selector.start_x, selector.cur_x)
    y2 = max(selector.start_y, selector.cur_y)
    root.destroy()
    return (x1, y1, x2, y2)


def screenshot_hash(image: Image.Image) -> str:
    return hashlib.md5(image.tobytes()).hexdigest()


def save_capture(image: Image.Image, text: str, output_dir: str):
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    images_dir = os.path.join(output_dir, "images")
    ocr_dir = os.path.join(output_dir, "ocr")
    os.makedirs(images_dir, exist_ok=True)
    os.makedirs(ocr_dir, exist_ok=True)
    image_path = os.path.join(images_dir, f"{timestamp}.png")
    ocr_path = os.path.join(ocr_dir, f"{timestamp}.txt")
    image.save(image_path)
    with open(ocr_path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"Saved capture to {image_path} and {ocr_path}")


def monitor_region(bbox, output_dir, interval=1.0):
    prev_hash = None
    with mss.mss() as sct:
        while True:
            sct_img = sct.grab({"left": bbox[0], "top": bbox[1], "width": bbox[2]-bbox[0], "height": bbox[3]-bbox[1]})
            img = Image.frombytes("RGB", sct_img.size, sct_img.rgb)
            current_hash = screenshot_hash(img)
            if current_hash != prev_hash:
                prev_hash = current_hash
                text = pytesseract.image_to_string(img)
                save_capture(img, text, output_dir)
            time.sleep(interval)


def main():
    print("Select region to monitor. Drag mouse over the desired area...")
    bbox = select_region()
    print(f"Monitoring region: {bbox}")
    output_dir = os.path.join(os.getcwd(), "captures")
    monitor_region(bbox, output_dir)


if __name__ == "__main__":
    main()
