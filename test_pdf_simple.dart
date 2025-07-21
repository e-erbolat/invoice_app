import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Test',
      home: PDFTestScreen(),
    );
  }
}

class PDFTestScreen extends StatefulWidget {
  @override
  _PDFTestScreenState createState() => _PDFTestScreenState();
}

class _PDFTestScreenState extends State<PDFTestScreen> {
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    try {
      // Используем встроенные шрифты с поддержкой кириллицы
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
      
      print('Шрифты загружены успешно');
      setState(() {}); // Обновляем UI
    } catch (e) {
      print('Ошибка загрузки шрифтов: $e');
    }
  }

  Future<void> _generateTestPDF() async {
    if (_regularFont == null || _boldFont == null) {
      print('Шрифты не загружены');
      return;
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Тест кириллицы в PDF', 
                style: pw.TextStyle(fontSize: 24, font: _boldFont)),
              pw.SizedBox(height: 20),
              pw.Text('Это тестовый документ для проверки отображения кириллицы', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Накладная №123456', 
                style: pw.TextStyle(fontSize: 18, font: _boldFont)),
              pw.Text('Торговая точка: ООО "Тестовая компания"', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Торговый представитель: Иванов Иван Иванович', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Дата: 18.07.2025', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Статус: передан', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Оплата: Не оплачен', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Сумма: 12345.67 ₸', 
                style: pw.TextStyle(font: _regularFont)),
              pw.SizedBox(height: 10),
              pw.Text('Товары:', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: _boldFont)),
              pw.Text('Молоко - 5 шт. × 150.00 ₸ = 750.00 ₸', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Хлеб - 3 шт. × 45.50 ₸ = 136.50 ₸', 
                style: pw.TextStyle(font: _regularFont)),
              pw.Text('Сыр - 2 шт. × 320.00 ₸ = 640.00 ₸', 
                style: pw.TextStyle(font: _regularFont)),
            ],
          );
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Тест PDF с кириллицей'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Статус шрифтов:'),
            Text(_regularFont != null && _boldFont != null 
              ? 'Загружены' 
              : 'Не загружены'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateTestPDF,
              child: Text('Сгенерировать тестовый PDF'),
            ),
          ],
        ),
      ),
    );
  }
} 