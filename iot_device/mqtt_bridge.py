import paho.mqtt.client as mqtt
import requests
import json
import sys
import time  # <--- Importante para manejar el límite de 60 segundos

# CONFIGURACIÓN DEL ENTORNO SMAT
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883
MQTT_TOPIC = "fisi/smat/estaciones/+/lecturas" 
API_URL = "http://localhost:8000/lecturas/"

# Token JWT generado previamente
JWT_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbl9maXNpIiwiZXhwIjoxNzgxMTM1MzgwfQ.eao0b4y_GJ6s9yDGghd5wD5F8mfIuJO1xo0U2F8SJZA"

# MEMORIA CACHÉ LOCAL
# Estructura: { estacion_id: {"ultimo_valor": float, "ultimo_tiempo": float} }
cache_estaciones = {}

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✔ Conectado exitosamente al Broker MQTT")
        client.subscribe(MQTT_TOPIC)
        print(f"📡 Escuchando transmisiones en el tópico: {MQTT_TOPIC}")
    else:
        print(f"❌ Error de conexión al Broker. Código de retorno: {rc}")
        sys.exit(1)

def on_message(client, userdata, msg):
    try:
        # 1. Decodificar el payload binario de MQTT a JSON string
        payload_raw = msg.payload.decode("utf-8")
        data_json = json.loads(payload_raw)

        # 2. Extraer el ID dinámico de la estación
        topic_parts = msg.topic.split('/')
        estacion_id = int(topic_parts[3])
        
        nuevo_valor = float(data_json["valor"])
        tiempo_actual = time.time()  # Timestamp actual en segundos

        print(f"\n[MQTT Recibido] Estación [{estacion_id}]: {nuevo_valor} cm")
  
        # LÓGICA DEL FILTRO (DEADBAND + TIMEOUT)
        enviar_a_api = False
        razon_envio = ""

        if estacion_id not in cache_estaciones:
            # Si es la primera vez que la estación reporta, se envía sí o sí
            enviar_a_api = True
            razon_envio = "Primera lectura registrada"
        else:
            datos_previos = cache_estaciones[estacion_id]
            ultimo_valor = datos_previos["ultimo_valor"]
            ultimo_tiempo = datos_previos["ultimo_tiempo"]

            # Criterio 1: Variación mayor al +- 5%
            # Evitamos división por cero por si acaso el último valor fue 0
            if ultimo_valor != 0:
                variacion_porcentual = abs(nuevo_valor - ultimo_valor) / ultimo_valor
            else:
                variacion_porcentual = 1.0 if nuevo_valor != 0 else 0.0

            if variacion_porcentual > 0.05:
                enviar_a_api = True
                razon_envio = f"Variación significativa del {variacion_porcentual*100:.2f}% (> 5%)"

            # Criterio 2: Alivio de tiempo (Pasaron más de 60 segundos)
            elif (tiempo_actual - ultimo_tiempo) > 60:
                enviar_a_api = True
                razon_envio = f"Timeout de vida alcanzado ({int(tiempo_actual - ultimo_tiempo)}s > 60s)"

        # PROCESAMIENTO O BLOQUEO DE LA PETICIÓN
        if enviar_a_api:
            print(f" 🚀 [Filtro PERMITIDO] -> {razon_envio}. Enviando a FastAPI...")
            
            # Formatear la carga útil para FastAPI
            api_payload = {
                "valor": nuevo_valor,
                "estacion_id": estacion_id
            }

            # Ingestión de datos segura mediante HTTP POST
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {JWT_TOKEN}"
            }
            
            response = requests.post(API_URL, json=api_payload, headers=headers)

            if response.status_code in [200, 201]:
                
                # Actualizamos la caché local SOLO si la base de datos confirmó el guardado
                cache_estaciones[estacion_id] = {
                    "ultimo_valor": nuevo_valor,
                    "ultimo_tiempo": tiempo_actual
                }
            else:
                print(f" ⚠️ [Fallo de Ingesta] API rechazó el dato. Código: {response.status_code} - {response.text}")
        else:
            # Aquí cumplimos la validación por logs que pide el entregable
            print(f"🛑 [Filtro BLOQUEADO] -> El valor {nuevo_valor} cm es redundante (no supera el ±5% ni los 60s).")

    except KeyError as e:
        print(f"❌ Error de esquema: Falta la llave {e} en el payload MQTT.")
    except ValueError:
        print("❌ Error de casteo: El valor o el ID de la estación no son numéricos.")
    except Exception as e:
        print(f"❌ Error crítico en el Bridge: {e}")

# Inicialización del cliente de red MQTT
bridge_client = mqtt.Client()
bridge_client.on_connect = on_connect
bridge_client.on_message = on_message

try:
    print("🚀 Inicializando el Bridge de Acoplamiento SMAT con Filtro Deadband...")
    bridge_client.connect(MQTT_BROKER, MQTT_PORT, 60)
    
    # Mantener el hilo escuchando activamente de forma síncrona
    bridge_client.loop_forever()
except KeyboardInterrupt:
    print("\n🛑 Bridge detenido por el administrador.")