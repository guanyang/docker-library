CREATE ROLE authenticator LOGIN NOINHERIT NOCREATEDB NOCREATEROLE NOSUPERUSER;
CREATE ROLE anonymous NOLOGIN;
CREATE ROLE webuser NOLOGIN;

CREATE TABLE employees
(
    id     BIGSERIAL PRIMARY KEY,
    name   VARCHAR(100),
    salary NUMERIC CHECK (salary > 0)
);

insert into employees (name, salary) values ('Jane Doe', 50000);
insert into employees (name, salary) values ('John Doe', 60000);
insert into employees (name, salary) values ('Jim Doe', 70000);

-- 创建视图以供 PostgREST 使用
CREATE VIEW employees_view AS
SELECT id, name, salary FROM employees;

-- 角色授权
GRANT SELECT ON employees_view TO webuser;
GRANT INSERT, UPDATE, DELETE ON employees TO webuser;

