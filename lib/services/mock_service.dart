import '../models/product.dart';
import '../models/outlet.dart';
import '../models/sales_rep.dart';
import '../models/invoice.dart';

class MockService {
  static final List<Product> _products = [
    Product(
      id: '1',
      name: 'Товар 1',
      description: 'Описание товара 1',
      price: 1000.0,
      category: 'Электроника',
      stockQuantity: 50,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      barcode: '123456789',
      satushiCode: 'SAT-001',
    ),
    Product(
      id: '2',
      name: 'Товар 2',
      description: 'Описание товара 2',
      price: 2000.0,
      category: 'Одежда',
      stockQuantity: 30,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      barcode: '987654321',
      satushiCode: 'SAT-002',
    ),
  ];

  static final List<Outlet> _outlets = [
    Outlet(
      id: '1',
      name: 'Торговая точка 1',
      address: 'ул. Примерная, 1',
      phone: '+7 777 123 45 67',
      contactPerson: 'Иван Иванов',
      region: 'Алматы',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Outlet(
      id: '2',
      name: 'Торговая точка 2',
      address: 'ул. Тестовая, 2',
      phone: '+7 777 234 56 78',
      contactPerson: 'Петр Петров',
      region: 'Астана',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<SalesRep> _salesReps = [
    SalesRep(
      id: '1',
      name: 'Алексей Сидоров',
      phone: '+7 777 345 67 89',
      email: 'alex@example.com',
      region: 'Алматы',
      commissionRate: 5.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    SalesRep(
      id: '2',
      name: 'Мария Козлова',
      phone: '+7 777 456 78 90',
      email: 'maria@example.com',
      region: 'Астана',
      commissionRate: 7.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  // Продукты
  Future<List<Product>> getProducts() async {
    await Future.delayed(Duration(milliseconds: 500)); // Имитация задержки сети
    return List.from(_products);
  }

  Future<void> addProduct(Product product) async {
    await Future.delayed(Duration(milliseconds: 300));
    final newProduct = Product(
      id: (_products.length + 1).toString(),
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      stockQuantity: product.stockQuantity,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      barcode: product.barcode,
      satushiCode: product.satushiCode,
    );
    _products.add(newProduct);
  }

  Future<void> updateProduct(Product product) async {
    await Future.delayed(Duration(milliseconds: 300));
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
    }
  }

  Future<void> deleteProduct(String productId) async {
    await Future.delayed(Duration(milliseconds: 300));
    _products.removeWhere((p) => p.id == productId);
  }

  // Торговые точки
  Future<List<Outlet>> getOutlets() async {
    await Future.delayed(Duration(milliseconds: 500));
    return List.from(_outlets);
  }

  Future<void> addOutlet(Outlet outlet) async {
    await Future.delayed(Duration(milliseconds: 300));
    final newOutlet = Outlet(
      id: (_outlets.length + 1).toString(),
      name: outlet.name,
      address: outlet.address,
      phone: outlet.phone,
      contactPerson: outlet.contactPerson,
      region: outlet.region,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _outlets.add(newOutlet);
  }

  Future<void> updateOutlet(Outlet outlet) async {
    await Future.delayed(Duration(milliseconds: 300));
    final index = _outlets.indexWhere((o) => o.id == outlet.id);
    if (index != -1) {
      _outlets[index] = outlet;
    }
  }

  Future<void> deleteOutlet(String outletId) async {
    await Future.delayed(Duration(milliseconds: 300));
    _outlets.removeWhere((o) => o.id == outletId);
  }

  // Торговые представители
  Future<List<SalesRep>> getSalesReps() async {
    await Future.delayed(Duration(milliseconds: 500));
    return List.from(_salesReps);
  }

  Future<void> addSalesRep(SalesRep salesRep) async {
    await Future.delayed(Duration(milliseconds: 300));
    final newSalesRep = SalesRep(
      id: (_salesReps.length + 1).toString(),
      name: salesRep.name,
      phone: salesRep.phone,
      email: salesRep.email,
      region: salesRep.region,
      commissionRate: salesRep.commissionRate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _salesReps.add(newSalesRep);
  }

  Future<void> updateSalesRep(SalesRep salesRep) async {
    await Future.delayed(Duration(milliseconds: 300));
    final index = _salesReps.indexWhere((s) => s.id == salesRep.id);
    if (index != -1) {
      _salesReps[index] = salesRep;
    }
  }

  Future<void> deleteSalesRep(String salesRepId) async {
    await Future.delayed(Duration(milliseconds: 300));
    _salesReps.removeWhere((s) => s.id == salesRepId);
  }

  // Накладные
  Future<List<Invoice>> getInvoices() async {
    await Future.delayed(Duration(milliseconds: 500));
    return [];
  }

  Future<void> addInvoice(Invoice invoice) async {
    await Future.delayed(Duration(milliseconds: 300));
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await Future.delayed(Duration(milliseconds: 300));
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await Future.delayed(Duration(milliseconds: 300));
  }
} 