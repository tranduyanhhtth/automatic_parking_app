OCR.Space integration

- Add your API key in the app: Menu -> Camera… -> OCR.Space API Key
- Key is stored under QSettings: Multimodel-AIThings/smart_parking_system, key: ocrSpaceApiKey
- Requires internet access. A 6s timeout is applied per request.
- We crop the largest detected plate box from each camera frame and send JPEG to https://api.ocr.space/parse/image.
- If no key is provided or the request fails, we fall back to "unknown" and continue offline.
