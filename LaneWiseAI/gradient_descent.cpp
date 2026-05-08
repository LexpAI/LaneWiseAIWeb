#include "gradient_descent.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <random>


gradient_descent::gradient_descent(GradientDescentType gd_type, double lr, double tol, int max_iter)
    : type(gd_type),
    learning_rate(lr),
    tolerance(tol),
    max_iterations(max_iter),
    batch_size(32),
    use_momentum(false),
    momentum_factor(0.9), 
    use_decay(false),
    decay_rate(0.9),
    decay_steps(100)
{ }

void gradient_descent::set_momentum(double factor)
{
    if(factor <= 0.0 || factor >= 1.0) {
        std::cerr << "Warning: Momentum factor should be between 0 and 1" << std::endl;
        return;
    }

    use_momentum = true;
    momentum_factor = factor;
}

void gradient_descent::set_learning_rate_decay(double rate, int steps)
{
    if(rate <= 0.0 || rate >= 1.0) {
        std::cerr << "Warning: Decay rate should be between 0 and 1" << std::endl;
        return;
    }

    if(steps <= 0) {
        std::cerr << "Warning: Decay steps should be positive" << std::endl;
        return;
    }

    use_decay = true;
    decay_rate = rate;
    decay_steps = steps;
}

void gradient_descent::set_batch_size(int size)
{
    if(size <= 0) {
        std::cerr << "Warning: Batch size should be positive" << std::endl;
        return;
    }

    batch_size = size;
}

std::vector<double> gradient_descent::optimize(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn)
{
    switch(type) {
    case GradientDescentType::BATCH:
        return batch_gradient_descent(initial_params, objective_fn, gradient_fn);
    case GradientDescentType::STOCHASTIC:
        return stochastic_gradient_descent(initial_params, objective_fn, gradient_fn);
    case GradientDescentType::MINI_BATCH:
        return mini_batch_gradient_descent(initial_params, objective_fn, gradient_fn);
    default:
        return initial_params;
    }
}

std::vector<double> gradient_descent::batch_gradient_descent(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn)
{
    std::vector<double> params = initial_params;
    previous_update = std::vector<double>(params.size(), 0.0);

    std::cout << "Starting Batch Gradient Descent..." << std::endl;
    std::cout << "Initial parameters: ";
    print_params(params);

    double current_lr = learning_rate;

    for(int iter = 0; iter < max_iterations; iter++) {
        std::vector<double> gradient = gradient_fn(params);

        if(use_decay && iter > 0 && iter % decay_steps == 0) {
            current_lr *= decay_rate;
            std::cout << "Learning rate decayed to: " << current_lr << std::endl;
        }

        if(use_momentum) {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] = momentum_factor * previous_update[i] + current_lr * gradient[i];
                previous_update[i] = gradient[i];
            }
        } else {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] *= current_lr;
            }
        }

        double max_change = 0.0;
        for(size_t i = 0; i < params.size(); i++) {
            double change = gradient[i];
            params[i] -= change;
            max_change = std::max(max_change, std::abs(change));
        }

        if(max_change < tolerance) {
            std::cout << "Converged after " << iter + 1 << " iterations" << std::endl;
            break;
        }

        if((iter + 1) % 100 == 0) {
            double objective_value = objective_fn(params);
            std::cout << "Iteration " << iter + 1 << ", Objective: " << objective_value << ", Max change: " << max_change << std::endl;
        }
    }

    std::cout << "Final parameters: ";
    print_params(params);

    return params;
}

std::vector<double> gradient_descent::stochastic_gradient_descent(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn)
{
    std::vector<double> params = initial_params;
    previous_update = std::vector<double>(params.size(), 0.0);

    std::cout << "Starting Stochastic Gradient Descent..." << std::endl;
    std::cout << "Initial parameters: ";
    print_params(params);

    double current_lr = learning_rate;
    std::random_device rd;
    std::mt19937 gen(rd());

    for(int iter = 0; iter < max_iterations; iter++) {
        std::vector<double> gradient = gradient_fn(params);

        if(use_decay && iter > 0 && iter % decay_steps == 0) {
            current_lr *= decay_rate;
            std::cout << "Learning rate decayed to: " << current_lr << std::endl;
        }

        std::normal_distribution<> noise(0.0, 0.1);
        for(size_t i = 0; i < gradient.size(); i++) {
            gradient[i] += noise(gen);
        }

        if(use_momentum) {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] = momentum_factor * previous_update[i] + current_lr * gradient[i];
                previous_update[i] = gradient[i];
            }
        } else {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] *= current_lr;
            }
        }

        double max_change = 0.0;
        for(size_t i = 0; i < params.size(); i++) {
            double change = gradient[i];
            params[i] -= change;
            max_change = std::max(max_change, std::abs(change));
        }

        if(max_change < tolerance) {
            std::cout << "Converged after " << iter + 1 << " iterations" << std::endl;
            break;
        }

        if((iter + 1) % 500 == 0) {
            double objective_value = objective_fn(params);
            std::cout << "Iteration " << iter + 1 << ", Objective: " << objective_value << ", Max change: " << max_change << std::endl;
        }
    }

    std::cout << "Final parameters: ";
    print_params(params);

    return params;
}

std::vector<double> gradient_descent::mini_batch_gradient_descent(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn)
{
    std::vector<double> params = initial_params;
    previous_update = std::vector<double>(params.size(), 0.0);

    std::cout << "Starting Mini-batch Gradient Descent..." << std::endl;
    std::cout << "Batch size: " << batch_size << std::endl;
    std::cout << "Initial parameters: ";
    print_params(params);

    double current_lr = learning_rate;

    for(int iter = 0; iter < max_iterations; iter++) {
        std::vector<double> gradient = gradient_fn(params);

        if(use_decay && iter > 0 && iter % decay_steps == 0) {
            current_lr *= decay_rate;
            std::cout << "Learning rate decayed to: " << current_lr << std::endl;
        }

        std::random_device rd;
        std::mt19937 gen(rd());
        std::normal_distribution<> noise(0.0, 0.05);
        for(size_t i = 0; i < gradient.size(); i++) {
            gradient[i] += noise(gen) / std::sqrt(batch_size);
        }

        if(use_momentum) {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] = momentum_factor * previous_update[i] + current_lr * gradient[i];
                previous_update[i] = gradient[i];
            }
        } else {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] *= current_lr;
            }
        }

        double max_change = 0.0;
        for(size_t i = 0; i < params.size(); i++) {
            double change = gradient[i];
            params[i] -= change;
            max_change = std::max(max_change, std::abs(change));
        }

        if(max_change < tolerance) {
            std::cout << "Converged after " << iter + 1 << " iterations" << std::endl;
            break;
        }

        if((iter + 1) % 200 == 0) {
            double objective_value = objective_fn(params);
            std::cout << "Iteration " << iter + 1 << ", Objective: " << objective_value << ", Max change: " << max_change << std::endl;
        }
    }

    std::cout << "Final parameters: ";
    print_params(params);

    return params;
}

gradient_descent::OptimizationResult gradient_descent::optimize_with_history(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn)
{
    OptimizationResult result;
    result.final_params = initial_params;
    result.converged = false;
    result.iterations_performed = 0;

    std::vector<double> params = initial_params;
    previous_update = std::vector<double>(params.size(), 0.0);

    double current_lr = learning_rate;
    result.objective_history.push_back(objective_fn(params));

    std::mt19937 gen(42u + static_cast<unsigned int>(type));

    for(int iter = 0; iter < max_iterations; iter++) {
        std::vector<double> gradient = gradient_fn(params);

        if(use_decay && iter > 0 && iter % decay_steps == 0) {
            current_lr *= decay_rate;
        }

        if(type == GradientDescentType::STOCHASTIC) {
            std::normal_distribution<> noise(0.0, 0.1);
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] += noise(gen);
            }
        } else if(type == GradientDescentType::MINI_BATCH) {
            std::normal_distribution<> noise(0.0, 0.05);
            const double batch_noise_scale = std::sqrt(static_cast<double>(std::max(batch_size, 1)));
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] += noise(gen) / batch_noise_scale;
            }
        }

        if(use_momentum) {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] = momentum_factor * previous_update[i] + current_lr * gradient[i];
                previous_update[i] = gradient[i];
            }
        } else {
            for(size_t i = 0; i < gradient.size(); i++) {
                gradient[i] *= current_lr;
            }
        }

        double max_change = 0.0;
        for(size_t i = 0; i < params.size(); i++) {
            double change = gradient[i];
            params[i] -= change;
            max_change = std::max(max_change, std::abs(change));
        }

        result.iterations_performed = iter + 1;
        result.objective_history.push_back(objective_fn(params));

        if(max_change < tolerance) {
            result.converged = true;
            break;
        }
    }

    result.final_params = params;
    result.final_objective_value = objective_fn(params);

    return result;
}

void gradient_descent::print_params(const std::vector<double>& params)
{
    std::cout << "[";
    for(size_t i = 0; i < params.size(); i++) {
        std::cout << params[i];
        if(i < params.size() - 1) std::cout << ", ";
    }
    std::cout << "]" << std::endl;
}

