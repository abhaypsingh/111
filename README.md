# Screen OCR Monitor

`screen_region_ocr.py` allows you to select a region of the screen and continuously monitor it. Whenever the contents of the region change, the tool saves a screenshot and the OCR text to the `captures/` directory.

## Usage

```bash
pip install mss pillow pytesseract
# make sure the `tesseract` binary is installed on your system
python screen_region_ocr.py
```

Drag the mouse to select the region when prompted. Captured images are placed in `captures/images/` and OCR text files in `captures/ocr/`.
