// 选择要操作的数据库
db = db.getSiblingDB('demo');

// 创建一个集合并插入一些初始数据
db.createCollection('employees');
db.employees.insertMany([
    { name: 'John Doe', position: 'Manager' },
    { name: 'Jane Smith', position: 'Developer' },
    { name: 'Alice Brown', position: 'Designer' }
]);

// 创建一个索引（可选）
db.employees.createIndex({ name: 1 });