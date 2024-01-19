import 'dart:io';

import 'package:logging/logging.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final _logger = Logger('FileSaver');

/// Saves the data [stream] to the [destinationPath].
/// [onProgress] will be called on every 100 ms.
Future<void> saveFile({
  required String destinationPath,
  required String name,
  required bool saveToGallery,
  required bool isImage,
  required Stream<List<int>> stream,
  required void Function(int savedBytes) onProgress,
}) async {
  final sink = File(destinationPath).openWrite();
  try {
    int savedBytes = 0;
    final stopwatch = Stopwatch()..start();
    await for (final event in stream) {
      sink.add(event);

      savedBytes += event.length;
      if (stopwatch.elapsedMilliseconds >= 100) {
        stopwatch.reset();
        onProgress(savedBytes);
      }
    }

    await sink.close();

    try {
      if (isImage) {
        final doc = pw.Document();

        final imageBytes = File(destinationPath).readAsBytesSync();
        final image = pw.MemoryImage(imageBytes);

        doc.addPage(pw.Page(
            pageFormat: PdfPageFormat.roll80,
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image));
            }));

        final print = await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => doc.save());

        if (print) {
          await File(destinationPath).delete();
          onProgress(savedBytes);
        }
      }
    } catch (_) {
      _logger.warning('Could not print file');
    }

    onProgress(savedBytes); // always emit final event
  } catch (_) {
    try {
      await sink.close();
      await File(destinationPath).delete();
    } catch (e) {
      _logger.warning('Could not delete file', e);
    }
    rethrow;
  }
}
