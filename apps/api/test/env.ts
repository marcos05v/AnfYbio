// Variables de las pruebas de integración. En la Mac usan la base
// anfybio_test; en GitHub Actions, DATABASE_URL viene del flujo de CI.
process.env.DATABASE_URL ??= `postgresql://${process.env.USER}@localhost:5432/anfybio_test`;
process.env.JWT_SECRET ??= 'clave-de-pruebas-de-al-menos-32-caracteres!!';
