import requests
import time
import random

BASE_URL = "http://localhost:8000"
API_URL = f"{BASE_URL}/lecturas/"

def obtener_token_maestro():
    login_url = f"{BASE_URL}/token" 
    try:
        headers = {"accept": "application/json", "Content-Length": "0"}
        response = requests.post(login_url, headers=headers, timeout=5) 
        if response.status_code == 200:
            return response.json().get("access_token")
        return None
    except Exception:
        return None

def obtener_ids_estaciones_dinamico():
    """Consulta al backend las estaciones reales creadas en el sistema"""
    url = f"{BASE_URL}/estaciones/"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            # Extraemos la lista de IDs de la respuesta JSON
            estaciones = response.json()
            ids = [estacion["id"] for estacion in estaciones]
            return ids
        return []
    except Exception:
        return []

def leer_sensor_emulado():
    return round(random.uniform(10.5, 85.0), 2)

def enviar_telemetria():
    print("--- Buscando estaciones activas en el sistema... ---")
    
    token = obtener_token_maestro()
    if not token:
        print("[CRÍTICO 🚨] No se pudo obtener el token de autorización.")
        return

    while True:
        # 🎯 AUTODETECCIÓN: Cada ciclo revisa si agregaste nuevas estaciones desde Flutter
        lista_estaciones = obtener_ids_estaciones_dinamico()
        
        if not lista_estaciones:
            print("[INFO ⚠️] No se encontraron estaciones creadas en la app. Creando reintento en 5 segundos...")
            time.sleep(5)
            continue
            
        # Selecciona un ID al azar de las estaciones reales que detectó en tu base de datos
        estacion_actual = random.choice(lista_estaciones)
        valor = leer_sensor_emulado()
        
        payload = {
            "valor": valor,
            "estacion_id": estacion_actual
        }
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "accept": "application/json"
        }
        
        try:
            response = requests.post(API_URL, json=payload, headers=headers, timeout=5)
            if response.status_code in [200, 201]:
                print(f"[OK ✅] Estación ID {estacion_actual} -> Registró: {valor} cm")
            elif response.status_code == 401:
                token = obtener_token_maestro()
        except Exception as e:
            print(f"[CRÍTICO 🔥] Error de conexión: {e}")

        time.sleep(3)

if __name__ == "__main__":
    enviar_telemetria()