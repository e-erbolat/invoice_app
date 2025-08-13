# Экспорт и импорт данных Firestore

Этот документ описывает, как экспортировать данные из одного Firestore проекта и импортировать их в другой.

## 📤 Экспорт данных

### Через приложение (рекомендуется)

1. **Войдите в приложение** как admin или superadmin
2. **Перейдите в раздел "Экспорт данных"** (📤 в главном меню)
3. **Выберите тип экспорта:**
   - **JSON** - для продуктов (удобно для импорта)
   - **Excel** - для продуктов (удобно для просмотра)
   - **Все данные** - полный экспорт всех коллекций

### Что экспортируется

- **products** - каталог товаров
- **outlets** - торговые точки
- **sales_reps** - торговые представители
- **invoices** - накладные
- **cash_register** - касса
- **cash_expenses** - расходы
- **users** - пользователи

### Формат экспорта

JSON файл содержит:
```json
{
  "exportDate": "2024-01-01T00:00:00.000Z",
  "collection": "products",
  "count": 100,
  "data": [
    {
      "documentId": "original_firestore_id",
      "id": "product_id",
      "name": "Название продукта",
      "price": 100.0,
      "description": "Описание",
      "category": "Категория",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

## 📥 Импорт данных

### Способ 1: Через Firebase Console

1. **Откройте Firebase Console** нового проекта
2. **Перейдите в Firestore Database**
3. **Создайте коллекции** с теми же именами
4. **Загрузите JSON файл** через консоль (если поддерживается)

### Способ 2: Через скрипт (рекомендуется)

1. **Скопируйте файл** `lib/utils/import_script.dart` в отдельный проект
2. **Настройте Firebase** в новом проекте
3. **Запустите скрипт:**

```bash
# Для импорта только продуктов
dart import_script.dart products_export_1234567890.json

# Для импорта всех данных
dart import_script.dart firestore_export_1234567890.json
```

### Способ 3: Через Firebase Admin SDK

```javascript
const admin = require('firebase-admin');
const fs = require('fs');

// Инициализация Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'your-new-project-id'
});

// Чтение JSON файла
const data = JSON.parse(fs.readFileSync('export.json', 'utf8'));

// Импорт данных
async function importData() {
  const db = admin.firestore();
  
  for (const collection of Object.keys(data.collections)) {
    const documents = data.collections[collection].data;
    
    for (const doc of documents) {
      const docId = doc.documentId;
      delete doc.documentId;
      
      if (docId) {
        await db.collection(collection).doc(docId).set(doc);
      } else {
        await db.collection(collection).add(doc);
      }
    }
  }
}

importData();
```

## 🔧 Настройка нового проекта

### 1. Создание Firebase проекта

1. Перейдите на [Firebase Console](https://console.firebase.google.com/)
2. Создайте новый проект
3. Включите Firestore Database
4. Настройте правила безопасности

### 2. Настройка правил Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Разрешаем доступ только аутентифицированным пользователям
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 3. Настройка аутентификации

1. Включите Email/Password аутентификацию
2. Создайте первого пользователя admin
3. Настройте пользовательские claims для ролей

### 4. Импорт данных

1. Запустите скрипт импорта
2. Проверьте данные в Firebase Console
3. Обновите конфигурацию приложения

## 📋 Контрольный список

### Перед экспортом:
- [ ] Проверьте права доступа к исходному проекту
- [ ] Убедитесь, что все данные актуальны
- [ ] Сделайте резервную копию

### После импорта:
- [ ] Проверьте количество документов в каждой коллекции
- [ ] Убедитесь, что ID документов сохранены
- [ ] Проверьте timestamp поля
- [ ] Протестируйте приложение с новыми данными

## ⚠️ Важные замечания

1. **ID документов** сохраняются для точного восстановления связей
2. **Timestamp поля** конвертируются в ISO 8601 формат
3. **Пароли пользователей** не экспортируются (нужно создать заново)
4. **Firebase Auth** настройки нужно настраивать отдельно
5. **Правила безопасности** нужно настроить вручную

## 🐛 Устранение проблем

### Ошибка "Permission denied"
- Проверьте правила безопасности Firestore
- Убедитесь, что пользователь имеет права на запись

### Ошибка "Invalid timestamp"
- Проверьте формат дат в JSON файле
- Убедитесь, что используется ISO 8601 формат

### Дублирование документов
- Проверьте, что ID документов уникальны
- Очистите коллекцию перед импортом при необходимости

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи в консоли
2. Убедитесь в правильности формата JSON
3. Проверьте настройки Firebase
4. Обратитесь к документации Firebase 