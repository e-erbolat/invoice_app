import 'package:flutter/material.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  @override
  _ImportScreenState createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ImportService _importService = ImportService();
  
  bool _isLoading = false;
  String? _selectedFileName;
  ImportResult? _lastImportResult;
  CollectionStats? _productsStats;
  CollectionStats? _outletsStats;
  CollectionStats? _salesRepsStats;
  
  // Прогресс импорта
  int _currentProgress = 0;
  int _totalProgress = 0;
  bool _showProgress = false;
  bool _skipExisting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productsStats = await _importService.getCollectionStats('products');
      final outletsStats = await _importService.getCollectionStats('outlets');
      final salesRepsStats = await _importService.getCollectionStats('sales_reps');

      setState(() {
        _productsStats = productsStats;
        _outletsStats = outletsStats;
        _salesRepsStats = salesRepsStats;
      });
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndImportFile(String collectionName) async {
    try {
      setState(() {
        _isLoading = true;
        _selectedFileName = null;
        _lastImportResult = null;
        _showProgress = false;
        _currentProgress = 0;
        _totalProgress = 0;
      });

      // Выбираем файл
      final jsonData = await _importService.pickJsonFile();
      if (jsonData == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _selectedFileName = 'Выбранный файл JSON';
        _showProgress = true;
      });

      // Импортируем данные с прогрессом
      final result = await _importService.importCollection(
        jsonData, 
        collectionName,
        onProgress: (current, total) {
          setState(() {
            _currentProgress = current;
            _totalProgress = total;
          });
        },
        skipExisting: _skipExisting,
      );
      
      setState(() {
        _lastImportResult = result;
        _isLoading = false;
        _showProgress = false;
      });

      // Обновляем статистику
      await _loadStats();

      // Показываем результат
      _showImportResult(result);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _showProgress = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка импорта: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImportResult(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Результат импорта'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📊 Всего записей: ${result.totalCount}'),
              SizedBox(height: 8),
              Text('✅ Успешно импортировано: ${result.successCount}'),
              SizedBox(height: 8),
              Text('❌ Ошибок: ${result.errorCount}'),
              SizedBox(height: 8),
              Text('📈 Процент успеха: ${result.successRate.toStringAsFixed(1)}%'),
              
              if (result.errors.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Ошибки:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  height: 200,
                  child: ListView.builder(
                    itemCount: result.errors.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${result.errors[index]}',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, CollectionStats? stats, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              stats?.documentCount.toString() ?? '0',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              'записей',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton(String title, String collectionName, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _isLoading ? null : () => _pickAndImportFile(collectionName),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                'Импорт из JSON',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Импорт данных'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStats,
            tooltip: 'Обновить статистику',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_showProgress) ...[
                    Text(
                      'Импорт данных...',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: _totalProgress > 0 ? _currentProgress / _totalProgress : 0,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '$_currentProgress из $_totalProgress',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '${_totalProgress > 0 ? ((_currentProgress / _totalProgress) * 100).toStringAsFixed(1) : 0}%',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ] else ...[
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Загрузка...'),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статистика
                  Text(
                    '📊 Статистика коллекций',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatsCard(
                          'Продукты',
                          _productsStats,
                          Icons.inventory,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatsCard(
                          'Торговые точки',
                          _outletsStats,
                          Icons.store,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatsCard(
                          'Торговые представители',
                          _salesRepsStats,
                          Icons.people,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: SizedBox()), // Пустое место для симметрии
                    ],
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Настройки импорта
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚙️ Настройки импорта',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          CheckboxListTile(
                            title: Text('Пропускать существующие записи'),
                            subtitle: Text('Не перезаписывать уже импортированные продукты'),
                            value: _skipExisting,
                            onChanged: (value) {
                              setState(() {
                                _skipExisting = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Кнопки импорта
                  Text(
                    '📥 Импорт данных',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildImportButton(
                          'Продукты',
                          'products',
                          Icons.inventory,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildImportButton(
                          'Торговые точки',
                          'outlets',
                          Icons.store,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildImportButton(
                          'Торговые представители',
                          'sales_reps',
                          Icons.people,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: SizedBox()), // Пустое место для симметрии
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Информация о формате
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ℹ️ Формат JSON файла',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Файл должен содержать структуру:\n'
                            '{\n'
                            '  "exportDate": "2025-08-01T20:04:48.588",\n'
                            '  "collection": "products",\n'
                            '  "count": 136,\n'
                            '  "data": [...]\n'
                            '}',
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_selectedFileName != null) ...[
                    SizedBox(height: 16),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.file_present, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Выбран файл: $_selectedFileName',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
} 