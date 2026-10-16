#pragma once

#include <condition_variable>
#include <cstddef>
#include <mutex>
#include <optional>
#include <queue>

// The bounded blocking queue `channel_pipeline` and `graph_churn_transfer` share:
// the C++ spelling of Prismio's `Channel<T>(capacity)`.
template <typename T>
class BoundedQueue
{
public:
    explicit BoundedQueue(size_t cap) : cap_(cap), closed_(false)
    {
    }

    void send(T val)
    {
        std::unique_lock<std::mutex> lock(mu_);
        not_full_.wait(lock, [this] { return queue_.size() < cap_ || closed_; });
        if (closed_) return;
        queue_.push(std::move(val));
        not_empty_.notify_one();
    }

    std::optional<T> recv()
    {
        std::unique_lock<std::mutex> lock(mu_);
        not_empty_.wait(lock, [this] { return !queue_.empty() || closed_; });
        if (queue_.empty()) return std::nullopt;
        T val = std::move(queue_.front());
        queue_.pop();
        not_full_.notify_one();
        return val;
    }

    void close()
    {
        std::unique_lock<std::mutex> lock(mu_);
        closed_ = true;
        not_full_.notify_all();
        not_empty_.notify_all();
    }

private:
    size_t cap_;
    bool closed_;
    std::mutex mu_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;
    std::queue<T> queue_;
};
