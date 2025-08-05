package asynccache

import (
	"context"
	"sync"
	"time"

	"k8s.io/klog/v2"
)

// AsyncCache provides asynchronous caching with background refresh
type AsyncCache[T any] struct {
	mutex       sync.RWMutex
	item        T
	fetchFunc   func(context.Context) (T, error)
	interval    time.Duration
	ctx         context.Context
	cancel      context.CancelFunc
	initialized bool
}

// NewAsyncCache creates a new async cache that refreshes items in the background
func NewAsyncCache[T any](ctx context.Context, interval time.Duration, fetchFunc func(context.Context) (T, error)) (*AsyncCache[T], error) {
	cache := &AsyncCache[T]{
		fetchFunc: fetchFunc,
		interval:  interval,
	}

	// Initial fetch
	item, err := fetchFunc(ctx)
	if err != nil {
		return nil, err
	}

	cache.item = item
	cache.initialized = true

	return cache, nil
}

// Run starts the background refresh loop
func (c *AsyncCache[T]) Run(ctx context.Context) {
	c.ctx, c.cancel = context.WithCancel(ctx)
	
	go c.refreshLoop()
}

// GetItem returns the cached item
func (c *AsyncCache[T]) GetItem() T {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	return c.item
}

// Stop stops the background refresh loop
func (c *AsyncCache[T]) Stop() {
	if c.cancel != nil {
		c.cancel()
	}
}

// refreshLoop runs the background refresh
func (c *AsyncCache[T]) refreshLoop() {
	ticker := time.NewTicker(c.interval)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			return
		case <-ticker.C:
			c.refresh()
		}
	}
}

// refresh updates the cached item
func (c *AsyncCache[T]) refresh() {
	klog.V(6).Info("Refreshing async cache item")
	
	item, err := c.fetchFunc(c.ctx)
	if err != nil {
		klog.Errorf("Failed to refresh cache item: %v", err)
		return
	}

	c.mutex.Lock()
	c.item = item
	c.mutex.Unlock()

	klog.V(6).Info("Successfully refreshed async cache item")
}