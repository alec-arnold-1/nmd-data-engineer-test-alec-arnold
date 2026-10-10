import sys
import json
import os
import logging
import pandas as pd
import urllib.parse
import awswrangler as wr

from orders_analytics import (
    add_profit_column,
    calculate_most_profitable_region,
    find_most_common_ship_method,
    find_number_of_order_per_category
)

"""
This lambda function performs the following actions

1. Find the most profitable Region, and its profit
2. Find what shipping method is most common for each Category
3. Output a glue table containing the number of orders for each Category and Sub Category
"""


logger = logging.getLogger()
logger.setLevel("INFO")

def get_s3_path_from_event(event : dict) -> str:
    "Returns the S3 path from the lambda event record"
    
    record = event["Records"][0] # grab first item in Records
    bucket = record["s3"]["bucket"]["name"] # get bucket name
    key = urllib.parse.unquote_plus(record['s3']['object']['key']) # get key without encoded characters
    return f"s3://{bucket}/{key}"

    

def lambda_handler(event, context):
    "Lambda function to process S3 events and perform analytics on orders data"

    try:

        # get glue database and output bucket environment variables
        output_bucket = os.environ["OUTPUT_BUCKET"]
        glue_database = os.environ["GLUE_DATABASE"]
        
        s3_path = get_s3_path_from_event(event) # Find the CSV file

        source_name = os.path.splitext(os.path.basename(s3_path))[0] # for example get "sample_orders" from the s3 path "s3://bucket/sample_orders.csv"
        # use this to get source file name for both the glue partition column and the csv output folders

        # Perform analytics on orders data
        orders_df = pd.read_csv(s3_path) # Read CSV from s3 path and put into pandas dataframe
        orders_df = add_profit_column(orders_df) # Add profit column first as most profitable region needs it
        top_region_df = calculate_most_profitable_region(orders_df)
        top_ship_df = find_most_common_ship_method(orders_df)
        order_counts_df = find_number_of_order_per_category(orders_df)

    

        # Write the dataframes to output bucket as CSV files / Glue table
        # Partitioning: each of the results of the input files get their own folderso that the files dont get overwritten

        top_region_df.to_csv(f"s3://{output_bucket}/top_region/source_file={source_name}/top_region.csv", index = False) # Most profitable region
        top_ship_df.to_csv(f"s3://{output_bucket}/top_ship/source_file={source_name}/top_ship.csv", index = False) # Most common shipping methods
        order_counts_df.to_csv(f"s3://{output_bucket}/order_counts/source_file={source_name}/order_counts.csv", index = False) # Order counts by category and subcategory

        wr.s3.to_parquet( # Order counts by category and subcategory
 
            df=order_counts_df.assign(source_file=source_name),  # add the partition column
            path=f"s3://{output_bucket}/order_counts_glue/",  # this is a folder not a file
            dataset=True,
            mode="overwrite_partitions",  # only replace this file's partition
            partition_cols=["source_file"],  # write into order_counts/source_file=<name>/
            database=glue_database,
            table="order_counts",
        )
    
        logger.info(f"Completed processing of {s3_path} and wrote to {output_bucket}")



    except Exception as e:
        logger.error(f"Error in processing the file {str(e)}")
        raise # raise so that lambda knows the run failed







