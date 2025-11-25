# 1. Usamos una imagen base ligera oficial de Python (Slim)
# Esto reduce el tamaño y la superficie de ataque.
FROM python:3.10-slim

# 2. Evitamos que Python escriba archivos .pyc y forzamos logs en tiempo real
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 3. Establecemos el directorio de trabajo dentro del contenedor
WORKDIR /app

# 4. Gestión de dependencias:
# Copiamos solo el requirements primero para aprovechar la caché de capas de Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copiamos el resto del código de la aplicación
COPY . .

# 6. SEGURIDAD: Crear un usuario no-root
# Por defecto Docker corre como root. Esto es peligroso.
# Creamos un usuario 'appuser' y le damos permisos sobre la carpeta /app
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser /app

# 7. Cambiamos al usuario seguro
USER appuser

# 8. Exponemos el puerto 8000 (donde corre FastAPI)
EXPOSE 8000

# 9. Comando de arranque
# Usamos uvicorn apuntando a la carpeta src.main y el objeto app
CMD ["uvicorn", "src.fastapi_app:app", "--host", "0.0.0.0", "--port", "8000"]