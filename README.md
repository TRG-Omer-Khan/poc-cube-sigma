# poc-cube-sigma

## STCS Data Architecture Stack

A complete data architecture implementation that federates PostgreSQL and Snowflake data through Trino, provides a semantic layer via Cube.js, and serves optimized data to Sigma Computing for business intelligence.

## Architecture

```
[PostgreSQL + Snowflake] → [Trino Federation] → [Cube.js Semantic Layer] → [Sigma BI]
```

## Components

### 1. Data Sources
- **PostgreSQL**: External database at `34.121.94.89:5432`
  - Database: `sales_db`
  - Contains: customers, orders, order_items, products tables
  
- **Snowflake**: Cloud data warehouse
  - Account: `BBVMZPQ-KA84846.snowflakecomputing.com`
  - Database: `SNOWFLAKE_LEARNING_DB`

### 2. Trino (Federation Layer)
- Provides unified SQL interface across multiple data sources
- Allows cross-database joins and queries
- Configured catalogs: `postgresql`, `snowflake`

### 3. Cube.js (Semantic Layer)
- Creates business metrics and KPIs
- Provides caching and pre-aggregations
- Exposes REST API and SQL API for BI tools
- Data models defined in YAML

### 4. Sigma Computing (BI Tool)
- Connects via Cube.js SQL API
- Uses PostgreSQL-compatible protocol
- Port: 15432

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Network access to external databases

### Start the Stack
```bash
./startup.sh
```

### Stop the Stack
```bash
docker-compose down
```

## Service Endpoints

| Service | URL/Port | Purpose |
|---------|----------|---------|
| Trino UI | http://localhost:8080 | Query engine interface |
| Cube.js API | http://localhost:4000 | REST API endpoint |
| Cube.js Playground | http://localhost:3001 | Development dashboard |
| Cube.js SQL | localhost:15432 | PostgreSQL-compatible SQL |

## Sigma Connection Configuration

1. Create new PostgreSQL connection in Sigma
2. Use these settings:
   - **Host**: `localhost` (or your server IP)
   - **Port**: `15432`
   - **Database**: `cube`
   - **Username**: `cube`
   - **Password**: `stcs-production-secret-2024`

## Data Models

### Cubes (Base Tables)
- `customers`: Customer master data
- `orders`: Order transactions
- `order_items`: Order line items
- `products`: Product catalog

### Views (Business Views)
- `sales`: Unified sales analysis view
- `customer_360`: Complete customer profile with orders
- `inventory_management`: Product inventory tracking

## Available Metrics

### Customer Metrics
- Total customers count
- Active customers
- Average lead score
- Customer by status/source

### Sales Metrics
- Total revenue
- Average order value
- Order count by status
- Payment method analysis

### Product Metrics
- Inventory value
- Products below reorder level
- Average price/cost
- Category performance

## Documentation

- **[Complete Project Documentation](COMPLETE_PROJECT_DOCUMENTATION.md)** - Comprehensive technical reference
- **[Production Setup Guide](PRODUCTION_SETUP.md)** - Deployment and configuration guide

## Troubleshooting

### Check Service Status
```bash
docker-compose ps
```

### View Service Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f cube
docker-compose logs -f trino-coordinator
```

### Test Trino Connection
```bash
curl http://localhost:8080/v1/info
```

### Test Cube.js API
```bash
curl http://localhost:4000/cubejs-api/v1/meta
```

## Architecture Benefits

- **Unified Analytics**: Query across PostgreSQL and Snowflake in single requests
- **Performance**: Cached aggregations and optimized query execution
- **Scalability**: Add new data sources without BI tool changes
- **Governance**: Centralized business logic and security
- **Developer Friendly**: Schema as code with version control

## Security Notes

⚠️ **For Production Use**:
1. Change all default passwords
2. Use environment variables for credentials
3. Enable SSL/TLS for all connections
4. Implement proper authentication
5. Set up network security groups
6. Enable audit logging

## Contributing

This is a proof-of-concept implementation. For production deployment, please review the security checklist and performance optimization guidelines in the complete documentation.