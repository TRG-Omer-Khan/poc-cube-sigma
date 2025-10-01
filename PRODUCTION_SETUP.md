# Production Setup Guide

## Current Status

✅ **Working Components**:
- Docker Compose orchestration
- Trino coordinator with memory catalog
- Cube.js semantic layer with REST API
- Basic infrastructure is operational

## To Connect Your External Databases

### 1. Enable PostgreSQL Catalog

Restore and configure the PostgreSQL catalog:

```bash
# Restore the PostgreSQL catalog
mv trino-config/catalog/postgresql.properties.bak trino-config/catalog/postgresql.properties

# Restart Trino
docker-compose restart trino-coordinator
```

### 2. Enable Snowflake Catalog

Restore and configure the Snowflake catalog:

```bash
# Restore the Snowflake catalog  
mv trino-config/catalog/snowflake.properties.bak trino-config/catalog/snowflake.properties

# Restart Trino
docker-compose restart trino-coordinator
```

### 3. Update Cube.js Models

Replace the demo cube models with your actual data models:

```bash
# Remove demo model
rm model/cubes/demo.yml

# Your original models are already in place:
# - model/cubes/customers.yml
# - model/cubes/orders.yml  
# - model/cubes/order_items.yml
# - model/cubes/products.yml
# - model/views/sales.yml
# - model/views/customer_360.yml
# - model/views/inventory_management.yml
```

### 4. Test Database Connectivity

Once you enable the PostgreSQL catalog, test the connection:

```bash
# Test Trino can connect to PostgreSQL
curl -X POST http://localhost:8080/v1/statement \\
  -H "Content-Type: application/json" \\
  -d '{"query": "SHOW TABLES FROM postgresql.public"}'

# Test Cube.js can compile your schemas
curl http://localhost:4000/cubejs-api/v1/meta
```

## Connecting Sigma Computing

### Option 1: SQL API (Recommended)
- **Host**: `localhost` (or your server IP)
- **Port**: `15432`
- **Database**: `cube`
- **Username**: `cube`
- **Password**: `stcs-production-secret-2024`
- **Type**: PostgreSQL

### Option 2: REST API
Use Cube.js REST API endpoints:
- Base URL: `http://localhost:4000/cubejs-api/v1/`
- Authentication: API Token required for production

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Trino UI | http://localhost:8080 | Query engine interface |
| Cube.js Dev Playground | http://localhost:3001 | Development dashboard |
| Cube.js REST API | http://localhost:4000 | REST API endpoint |
| Cube.js SQL API | localhost:15432 | PostgreSQL-compatible SQL |

## Troubleshooting

### Trino Connection Issues
1. Verify external database connectivity
2. Check credentials in catalog properties files
3. Ensure firewall allows connections
4. Check logs: `docker-compose logs trino-coordinator`

### Cube.js Schema Issues
1. Ensure Trino is running and accessible
2. Verify catalog names match in cube models
3. Check table names exist in your databases
4. Review logs: `docker-compose logs cube`

### Sigma Connection Issues
1. Test SQL API with psql first
2. Verify port 15432 is accessible
3. Check username/password combination
4. Ensure Cube.js models are compiled successfully

## Next Steps

1. **Enable External Databases**: Follow steps above to connect PostgreSQL and Snowflake
2. **Update Security**: Change default passwords and API secrets
3. **Configure SSL**: Enable SSL/TLS for production use
4. **Set up Monitoring**: Add logging and monitoring solutions
5. **Scale Services**: Configure resource limits and scaling policies

## Sample Queries for Testing

Once connected to your external databases, test with these queries:

```sql
-- Test in Trino UI
SELECT COUNT(*) FROM postgresql.public.customers;
SELECT COUNT(*) FROM snowflake.public.your_table;

-- Test through Cube.js SQL API
SELECT * FROM customers LIMIT 10;
SELECT 
  customers_company,
  COUNT(*) as customer_count
FROM sales 
GROUP BY customers_company 
ORDER BY customer_count DESC 
LIMIT 10;
```

## Production Checklist

- [ ] External database connectivity tested
- [ ] All Cube.js models compiled successfully  
- [ ] Sigma connection established and tested
- [ ] Security credentials updated
- [ ] SSL/TLS configured
- [ ] Monitoring and logging in place
- [ ] Backup and recovery procedures documented
- [ ] Performance testing completed