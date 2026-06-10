import requests
import time
import random
import json  # <--- Importante para dar formato al payload de MQTT
import paho.mqtt.client as mqtt  # <---Librería MQTT para telemetría

BASE_URL = "http://localhost:8000"
# Cambiamos las variables de HTTP por las variables de red del Broker MQTT
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883

def obtener_ids_estaciones_dinamico():
    """Consulta al backend las estaciones reales creadas en el sistema"""
    url = f"{BASE_URL}/estaciones/"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            estaciones = response.json()
            ids = [estacion["id"] for estacion in estaciones]
            return ids
        return []
    except Exception:
        return []

def leer_sensor_emulado():
    return round(random.uniform(10.5, 85.0), 2)

def enviar_telemetria():
    print("--- Inicializando Emisor de Telemetría SMAT (Vía MQTT) ---")
    
    # 1. Inicializamos el cliente MQTT y nos conectamos al Broker público
    mqtt_client = mqtt.Client()
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        print("✔ Sensor conectado exitosamente al Broker MQTT de HiveMQ")
    except Exception as e:
        print(f"[CRÍTICO 🚨] No se pudo conectar al Broker MQTT: {e}")
        return

    while True:
        # 🎯 Tu lógica original de AUTODETECCIÓN se mantiene idéntica
        lista_estaciones = obtener_ids_estaciones_dinamico()
        
        if not lista_estaciones:
            print("[INFO ⚠️] No se encontraron estaciones creadas en la app. Creando reintento en 5 segundos...")
            time.sleep(5)
            continue
            
        # Selecciona un ID al azar de las estaciones reales de tu base de datos
        estacion_actual = random.choice(lista_estaciones)
        valor = leer_sensor_emulado()
        
        # 2. Creamos el tópico dinámico que tu Bridge está escuchando
        # Cambiamos el comodín '+' por el ID real de la estación (ej: fisi/smat/estaciones/3/lecturas)
        TOPIC = f"fisi/smat/estaciones/{estacion_actual}/lecturas"
        
        # 3. Empaquetamos el valor en un formato JSON String que el Bridge pueda leer
        payload = json.dumps({
            "valor": valor
        })
        
        try:
            # 🔥 Aquí reemplazamos tu requests.post por el envío directo al Broker MQTT
            mqtt_client.publish(TOPIC, payload)
            print(f"[OK ✅] Estación ID {estacion_actual} -> Publicado por MQTT: {valor} cm")
        except Exception as e:
            print(f"[CRÍTICO 🔥] Error al transmitir por MQTT: {e}")

        # Mantenemos tus 3 segundos de espera originales
        time.sleep(3)

if __name__ == "__main__":
    enviar_telemetria()