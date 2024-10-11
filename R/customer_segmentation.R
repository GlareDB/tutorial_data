options( warn = -1)


# 0. Installation, set-up, and gathering our data
# Installation
install.packages("glaredb", repos = "https://community.r-multiverse.org")
install.packages(c("dplyr", "ggplot2", "factoextra", "scales", "tidyr"))

# Import
library(glaredb)
library(dplyr)
library(ggplot2)
library(factoextra)
library(scales)
library(tidyr)

# Set up our connection
con <- glaredb_connect()

# Inspect the data
glaredb_sql("
  SELECT * FROM read_postgres(
    'postgresql://postgres:postgres@localhost:5433/postgres', 
    'public',
    'transactions'
  ) LIMIT 5
", con) |> as.data.frame()

glaredb_sql("
  SELECT timestamp::datetime FROM 'clickstream.json' LIMIT 5
", con) |> as.data.frame()

# Join data for analysis
customer_data <- glaredb_sql("
  SELECT 
    t.customer_id, 
    COUNT(DISTINCT t.transaction_id) as num_transactions,
    AVG(t.amount) as avg_transaction_amount,
    SUM(t.amount) as total_spent,
    COUNT(c.event_id) as total_events,
    SUM(CASE WHEN c.action = 'purchase' THEN 1 ELSE 0 END) as num_purchases,
    SUM(CASE WHEN c.action = 'add_to_cart' THEN 1 ELSE 0 END) as num_add_to_cart,
    SUM(CASE WHEN c.page_view = 'product' THEN 1 ELSE 0 END) as product_page_views
  FROM read_postgres(
    'postgresql://postgres:postgres@localhost:5433/postgres', 
    'public',
    'transactions'
  ) AS t
  JOIN 'clickstream.json' AS c 
    ON t.customer_id = c.customer_id
  GROUP BY t.customer_id
", con) |> as.data.frame()

head(customer_data)

# 1. Prepare data for clustering
# Select features for clustering and normalize them
features <- customer_data |>
  select(-customer_id) |>
  scale()

# 2. Determine optimal number of clusters using elbow plot
set.seed(123)
wss <- sapply(1:10, function(k){kmeans(features, k, nstart=50, iter.max = 15)$tot.withinss})
elbow_plot <- ggplot(data.frame(k=1:10, wss=wss), aes(x=k, y=wss)) +
  geom_line() +
  geom_point() +
  scale_x_continuous(breaks=1:10) +
  labs(x="Number of Clusters (k)", y="Total Within-Cluster Sum of Squares") +
  theme_minimal() +
  ggtitle("Elbow Method for Optimal k")

print(elbow_plot)

# Based on the elbow plot, let's choose k=3 for this example
# You might choose a different k based on your specific elbow plot

# 3. Perform K-means clustering
set.seed(123)
kmeans_result <- kmeans(features, centers = 3, nstart = 25)
kmeans_result

# 4. Add cluster assignments to the original data
customer_segments <- customer_data |>
  mutate(cluster = kmeans_result$cluster)

head(customer_segments)

# 5. Visualize the clusters using specific features
ggplot(customer_segments, aes(x = total_spent, y = num_purchases, color = factor(cluster))) +
  geom_point(alpha = 0.6) +
  theme_minimal() +
  labs(x = "Total Spent", y = "Number of Purchases", color = "Cluster") +
  ggtitle("Customer Segments Visualization")

# 6. Analyze cluster characteristics
segment_summary <- customer_segments |>
  group_by(cluster) |>
  summarize(across(where(is.numeric), ~ round(mean(.), 2))) |>
  select(-customer_id) |>  # Remove customer_id from summary
  arrange(desc(total_spent))

print(segment_summary)

# 7. Visualize key differences between clusters
long_summary <- segment_summary %>%
  pivot_longer(cols = -cluster, names_to = "metric", values_to = "value")

ggplot(long_summary, aes(x = metric, y = value, fill = factor(cluster))) +
  geom_bar(stat = "identity", position = "dodge") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_y_continuous(labels = comma) +
  labs(x = "Metric", y = "Value", fill = "Cluster") +
  ggtitle("Comparison of Clusters Across Metrics")


# 8. Interpret and name the clusters
cluster_names <- c("1" = "Potential Converters",
                   "2" = "High Activity and Spend",
                   "3" = "Mid Browsers")

customer_segments <- customer_segments %>%
  mutate(segment_name = cluster_names[as.character(cluster)])

# Display distribution of segments
segment_distribution <- customer_segments %>%
  count(segment_name) %>%
  mutate(percentage = n / sum(n) * 100)

print(segment_distribution)

# 9. Feature importance
cluster_centers <- kmeans_result$centers
feature_importance <- apply(cluster_centers, 2, var)
feature_importance_df <- data.frame(
  feature = names(feature_importance),
  importance = feature_importance
) %>%
  arrange(desc(importance))

ggplot(feature_importance_df, aes(x = reorder(feature, importance), y = importance)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  theme_minimal() +
  labs(x = "Feature", y = "Importance (Variance)") +
  ggtitle("Feature Importance in Clustering")