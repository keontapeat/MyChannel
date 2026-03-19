"""
Connection Pool Manager for Cloud Run Services
Reduces latency by reusing connections
"""

import asyncio
from typing import Dict, Optional
import aiohttp
from functools import lru_cache
import logging

logger = logging.getLogger(__name__)


class ConnectionPoolManager:
    """Manages HTTP connection pools for ML agent services"""
    
    def __init__(self, max_connections: int = 100, timeout: int = 30):
        self.max_connections = max_connections
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self._session: Optional[aiohttp.ClientSession] = None
        self._connector: Optional[aiohttp.TCPConnector] = None
        
    async def get_session(self) -> aiohttp.ClientSession:
        """Get or create shared session with connection pooling"""
        if self._session is None or self._session.closed:
            self._connector = aiohttp.TCPConnector(
                limit=self.max_connections,
                limit_per_host=20,
                ttl_dns_cache=300,  # 5 min DNS cache
                enable_cleanup_closed=True,
                force_close=False,  # Reuse connections
            )
            
            self._session = aiohttp.ClientSession(
                connector=self._connector,
                timeout=self.timeout,
                headers={
                    'User-Agent': 'MyChannel-ML-Client/1.0',
                    'Connection': 'keep-alive',
                }
            )
            
            logger.info(f"🔥 Connection pool created: {self.max_connections} max connections")
        
        return self._session
    
    async def close(self):
        """Close session and connections"""
        if self._session and not self._session.closed:
            await self._session.close()
            logger.info("👋 Connection pool closed")
    
    async def request(
        self,
        method: str,
        url: str,
        **kwargs
    ) -> Dict:
        """Make HTTP request with connection pooling"""
        session = await self.get_session()
        
        try:
            async with session.request(method, url, **kwargs) as response:
                response.raise_for_status()
                return await response.json()
        except aiohttp.ClientError as e:
            logger.error(f"❌ Request failed: {url} - {e}")
            raise
    
    async def batch_request(
        self,
        requests: list[Dict]
    ) -> list[Dict]:
        """Execute multiple requests in parallel"""
        tasks = [
            self.request(
                req['method'],
                req['url'],
                **req.get('kwargs', {})
            )
            for req in requests
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Filter out exceptions
        return [r for r in results if not isinstance(r, Exception)]


# Global connection pool instance
_pool: Optional[ConnectionPoolManager] = None


def get_connection_pool() -> ConnectionPoolManager:
    """Get global connection pool instance"""
    global _pool
    if _pool is None:
        _pool = ConnectionPoolManager()
    return _pool


@lru_cache(maxsize=1000)
def get_service_url(service_name: str) -> str:
    """Get Cloud Run service URL with caching"""
    base_url = "https://{}-fkri6ifojq-uc.a.run.app"
    return base_url.format(service_name)


async def call_ml_service(
    service_name: str,
    endpoint: str = "/predict",
    data: Dict = None,
    method: str = "POST"
) -> Dict:
    """
    Call ML service with connection pooling
    
    Args:
        service_name: Name of the ML service
        endpoint: API endpoint path
        data: Request payload
        method: HTTP method
    
    Returns:
        Response data
    """
    pool = get_connection_pool()
    url = f"{get_service_url(service_name)}{endpoint}"
    
    kwargs = {}
    if data:
        kwargs['json'] = data
    
    logger.info(f"🚀 Calling ML service: {service_name}{endpoint}")
    start_time = asyncio.get_event_loop().time()
    
    try:
        result = await pool.request(method, url, **kwargs)
        
        elapsed = (asyncio.get_event_loop().time() - start_time) * 1000
        logger.info(f"✅ ML service response: {service_name} ({elapsed:.0f}ms)")
        
        return result
    except Exception as e:
        elapsed = (asyncio.get_event_loop().time() - start_time) * 1000
        logger.error(f"❌ ML service failed: {service_name} ({elapsed:.0f}ms) - {e}")
        raise


async def batch_call_ml_services(
    calls: list[Dict]
) -> list[Dict]:
    """
    Call multiple ML services in parallel
    
    Args:
        calls: List of service call configs
            [{'service': 'name', 'endpoint': '/predict', 'data': {...}}]
    
    Returns:
        List of responses
    """
    pool = get_connection_pool()
    
    requests = [
        {
            'method': call.get('method', 'POST'),
            'url': f"{get_service_url(call['service'])}{call.get('endpoint', '/predict')}",
            'kwargs': {'json': call.get('data')} if call.get('data') else {}
        }
        for call in calls
    ]
    
    logger.info(f"🔥 Batch calling {len(requests)} ML services")
    start_time = asyncio.get_event_loop().time()
    
    results = await pool.batch_request(requests)
    
    elapsed = (asyncio.get_event_loop().time() - start_time) * 1000
    logger.info(f"✅ Batch complete: {len(results)}/{len(requests)} succeeded ({elapsed:.0f}ms)")
    
    return results


# Cleanup on shutdown
import atexit

@atexit.register
def cleanup():
    """Cleanup connection pool on shutdown"""
    if _pool:
        asyncio.run(_pool.close())
