// api/mobile-bootstrap.js - Dedicated Mobile Bootstrap Endpoint
// Cleaner URL: /api/mobile-bootstrap instead of /api/bootstrap?platform=mobile
// This file wraps the main bootstrap with platform=mobile preset

import handler from './bootstrap.js';

export default async function mobileBootstrapHandler(req, res) {
  // Force platform to mobile
  req.query.platform = 'mobile';
  
  // Call the main bootstrap handler
  return handler(req, res);
}
