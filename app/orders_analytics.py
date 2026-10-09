import pandas as pd
"Complete these functions or write your own to perform the following tasks"

def add_profit_column(orders_df):
    "Add a profit column for each order in the DataFrame"

    sale_price = orders_df['List Price'] * (1 - orders_df['Discount Percent'] / 100)
    orders_df['Profit'] = (sale_price - orders_df['cost price']) * orders_df['Quantity']

    return orders_df

def calculate_most_profitable_region(orders_df):
    "Calculate the most profitable region and its profit"

    by_region_df = orders_df.groupby('Region', as_index=False)['Profit'].sum()
    top_region_df = by_region_df.nlargest(1, 'Profit')
   
    return top_region_df

def find_most_common_ship_method(orders_df):
    "Find the most common shipping method for each Category"

    top_ship_df = (orders_df.groupby('Category')['Ship Mode']
    # For a tie in frequency, the tied ship modes are sorted and joined with a semicolon
    .agg(lambda s: '; '.join(sorted(s.mode())))
    .reset_index()
    )
    
    return top_ship_df

def find_number_of_order_per_category(orders_df):
    "find the number of orders for each Category and Sub Category"
    order_counts_df = (
    orders_df.groupby(['Category', 'Sub Category'], as_index=False)['Order Id']
    .nunique()
    .rename(columns={'Order Id': 'Order Count'})
    )

    return order_counts_df