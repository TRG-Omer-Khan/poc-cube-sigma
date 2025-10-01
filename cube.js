module.exports = {
  contextToAppId: ({ securityContext }) => {
    return 'CUBEJS_APP';
  },
  
  preAggregationsSchema: ({ securityContext }) => {
    return 'pre_aggregations';
  },
  
  scheduledRefreshTimer: 60,
  
  orchestratorOptions: {
    redisPrefix: 'CUBEJS_APP'
  },
  
  // Enable SQL API
  sqlPort: process.env.CUBEJS_SQL_PORT || 15432,
  pgSqlPort: process.env.CUBEJS_PG_SQL_PORT || 15432,
  
  // SQL API authentication
  checkSqlAuth: (req, username) => {
    const expectedUser = process.env.CUBEJS_SQL_USER || 'cube';
    const expectedPassword = process.env.CUBEJS_SQL_PASSWORD || 'stcs-production-secret-2024';
    
    if (username === expectedUser && req.password === expectedPassword) {
      return {
        securityContext: {},
        superuser: true
      };
    }
    
    throw new Error('Incorrect user name or password');
  },
  
  // Enable development mode features
  devServer: process.env.CUBEJS_DEV_MODE === 'true',
  
  // Query caching is enabled by default in newer versions
  
  // Logging
  logger: (msg, params) => {
    console.log(`${msg}: ${JSON.stringify(params)}`);
  }
};