// 选择要操作的数据库
db = db.getSiblingDB('demo');

// 创建一个集合并插入一些初始数据
db.createCollection('employees');
db.employees.insertMany([
    { name: "John", position: "Manager", salary: 5000, age: 45 },
    { name: "Jane", position: "Developer", salary: 4000, age: 28 },
    { name: "Alice", position: "Designer", salary: 3500, age: 32 },
    { name: "Bob", position: "Developer", salary: 4200, age: 29 },
    { name: "Charlie", position: "Manager", salary: 5500, age: 50 }
]);

// 创建一个索引（可选）
db.employees.createIndex({ position: 1, salary: -1 })