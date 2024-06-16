import streamlit as st
import glaredb
import pgeocode

# Get your GlareDB connection
con = glaredb.connect(
    "glaredb://6AhiEN7GQDmo:<PASSWORD>@o_PRocU0j.remote.glaredb.com:6443/rough_glitter"
)

# Set up the dataframes to use for plotting
sales_over_time_df = con.sql(
    """
        select DATE_TRUNC('month', "SALE DATE") as sale_date, COUNT(*) as ct from nyc_sales GROUP BY sale_date
        ORDER BY sale_date DESC
    """
).to_pandas()

zip_code_df = con.sql(
    """
        select "ZIP CODE" as zip_code, COUNT(*) as ct from nyc_sales
        WHERE ("ZIP CODE" IS NOT NULL)
        AND ("ZIP CODE" <> 0)
        GROUP BY "ZIP CODE"
    """
).to_pandas()

# Use pgeocode to get the lat/long coordinates for plotting
nomi = pgeocode.Nominatim('us')
def get_lat_long(nomi: pgeocode.Nominatim, zip_code: int):
    qpc = nomi.query_postal_code(zip_code)
    return {
        "lat": qpc.latitude,
        "long": qpc.longitude
    }

zip_code_df[["lat", "long"]] = zip_code_df.apply(
    lambda row: get_lat_long(nomi, int(row['zip_code'])), axis=1, result_type="expand"
)


st.set_page_config(layout="wide")

st.title('NYC sales dashboard')

# Use two columns in the Streamlit dashboard
col1, col2 = st.columns(2)

with col1:
    st.header("Count of NYC real estate sales by month")
    st.line_chart(sales_over_time_df, x="sale_date", height=540)

with col2:
    st.header("NYC real estate sales by zip code")
    st.map(data=zip_code_df.dropna(), latitude="lat", longitude="long", size="ct")