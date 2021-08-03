# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for
# full license information.

import os
import sys
import json
import time
import pyodbc
import asyncio
import logging
import threading
from six.moves import input
from azure.iot.device.aio import IoTHubModuleClient

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] %(message)s", "%Y-%m-%d %H:%M:%S")
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(formatter)
logger.addHandler(handler)

sql_server = os.environ["SQL_SERVER"]
sql_database = os.environ["SQL_DATABASE"]
sql_username = os.environ["SQL_USERNAME"]
sql_password = os.environ["SQL_PASSWORD"]
models_table = os.environ["SQL_MODELS_TABLE"]
features_table = os.environ["SQL_FEATURES_TABLE"]
models_id_column_name = os.environ["SQL_MODELS_ID_COLUMN_NAME"]
models_trigger_column_name = os.environ["SQL_MODELS_TRIGGER_COLUMN_NAME"]
timer_seconds = int(os.environ["TIMER_SECONDS"])

def get_connection_string(server, database, username, password):
    db_connection_string = f'Driver={{ODBC Driver 17 for SQL Server}};Server={server};UID={username};PWD={password};Database={database};'
    return db_connection_string

def score_module(entry):
    score = None
    try:
        # create connector
        db_connection_string = get_connection_string(sql_server, sql_database, sql_username, sql_password)
        conn = pyodbc.connect(db_connection_string, autocommit=True)
        cursor = conn.cursor()

        # retrieve respective model
        application_uri = entry['ApplicationUri']
        query_condition = f'{models_id_column_name}="{application_uri}"'
        query = f'SELECT * FROM dbo.{models_table} WHERE {query_condition}'

        logger.info(f'ONNX model query: ')
        logger.info(query)

        cursor.execute(query)
        rows = cursor.fetchall()

        if len(rows) != 0:
            model = rows[0]
            logger.info(f'Using model id {model.id}')

            # predict model
            query = f'''
            WITH predict_input
            AS (SELECT TOP 1 
                    DipData
                    , SpikeData
                    , RandomSignedInt32
                FROM
                    dbo.{features_table})
            SELECT
                predict_input.id
                , p.variable1 AS SCORE
            FROM PREDICT(MODEL = {model.data}, DATA = predict_input, RUNTIME=ONNX) WITH (variable1 FLOAT) AS p;'''

            logger.info('predict query:')
            logger.info(query)

            cursor.execute(query)
            rows = cursor.fetchall()

            if len(rows) != 0:
                score = rows[0]
            else:
                logging.error("PREDICT query did not return any values")
        else:
            logging.error(f'Unable to retrieve model from table {models_table} with the following condition: {query_condition}')

        return score
    except Exception as e:
        logging.exception(e)
        return score

async def main():
    try:
        if not sys.version >= "3.5.3":
            raise Exception( "The sample requires python 3.5.3+. Current version of Python: %s" % sys.version )
        logger.info("IoT Hub Client for Python")

        # The client object is used to interact with your Azure IoT hub.
        module_client = IoTHubModuleClient.create_from_edge_environment()
        
        # connect the client.
        await module_client.connect()

        async def message_handler(message):
            try:
                logger.info(f'Received new input message: ')
                logger.info(message)

                # score = score_module(message)
                # output_message = {
                #     'score': score
                # }
                
                # logger.info("output message data: ")
                # logger.info(output_message)
                # await module_client.send_message_to_output(output_message, "output1")
            except Exception as e:
                logger.exception(e)

        # define behavior for halting the application
        def infinite_loop():
            counter = 0
            while True:
                try:
                    counter += 1
                    logger.info(f'Counter: {counter}')
                    time.sleep(timer_seconds)
                except:
                    time.sleep(timer_seconds)

        # Schedule task for C2D Listener
        module_client.on_message_received = message_handler

        logger.info("Module is now waiting for messages.")

        # Run the stdin listener in the event loop
        loop = asyncio.get_event_loop()
        infinite_loop = loop.run_in_executor(None, infinite_loop)

        # Wait for user to indicate they are done listening for messages
        await infinite_loop

        # Finally, disconnect
        await module_client.disconnect()

    except Exception as e:
        logger.exception(e)
        raise

if __name__ == "__main__":
    # loop = asyncio.get_event_loop()
    # loop.run_until_complete(main())
    # loop.close()

    # If using Python 3.7 or above, you can use following code instead:
    asyncio.run(main())