import 'dart:io';

void main() async {
  final pdfPath = r'C:\Users\ravim\.gemini\antigravity-ide\brain\a2e3f22c-63d8-4684-809b-8678339211c6\.user_uploaded\media_1791619577167.pdf';
  final file = File(pdfPath);
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }

  final bytes = await file.readAsBytes();
  print('PDF size: ${bytes.length} bytes');

  // Search for JPEG markers: 0xFF, 0xD8, 0xFF ... 0xFF, 0xD9
  int count = 0;
  int i = 0;
  while (i < bytes.length - 1) {
    if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
      int start = i;
      int end = -1;
      for (int j = start + 2; j < bytes.length - 1; j++) {
        if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
          end = j + 2;
          break;
        }
      }
      if (end != -1 && (end - start) > 10000) {
        count++;
        final imgBytes = bytes.sublist(start, end);
        final outName = 'assets/images/extracted_$count.jpg';
        File(outName).writeAsBytesSync(imgBytes);
        print('Extracted JPEG $count: ${imgBytes.length} bytes -> $outName');
        i = end;
        continue;
      }
    }
    i++;
  }
  print('Total JPEGs extracted: $count');
}
