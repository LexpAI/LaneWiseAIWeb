#ifndef __GRADIENT_DESCENT_HPP
#define __GRADIENT_DESCENT_HPP

#include <vector>
#include <functional>
#include <string>

struct RouteRecord {
    std::string origin;
    std::string destination;
    double distance_mi;   
    double weight_kg;    
    int pallet_count;      
    int service_level;      
    double cost_usd;        
};

using ObjectiveFunction = std::function<double(const std::vector<double>&)>;
using GradientFunction = std::function<std::vector<double>(const std::vector<double>&)>;

enum class GradientDescentType {
    BATCH,
    STOCHASTIC,
    MINI_BATCH
};

class gradient_descent
{
    GradientDescentType type;
    double learning_rate;
    double tolerance;
    int max_iterations;
    int batch_size;
    bool use_momentum;
    double momentum_factor;
    std::vector<double> previous_update;

    bool use_decay;
    double decay_rate;
    int decay_steps;

public:
    gradient_descent(GradientDescentType gd_type = GradientDescentType::BATCH,
                     double lr = 0.01,
                     double tol = 1e-6,
                     int max_iter = 1000);

    void set_momentum(double factor);
    void set_learning_rate_decay(double rate, int steps);
    void set_batch_size(int size);

    std::vector<double> optimize(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn);
    std::vector<double> batch_gradient_descent(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn);
    std::vector<double> stochastic_gradient_descent(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn);

    std::vector<double> mini_batch_gradient_descent(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn);

    struct OptimizationResult {
        std::vector<double> final_params;
        double final_objective_value;
        int iterations_performed;
        std::vector<double> objective_history;
        bool converged;
    };

    OptimizationResult optimize_with_history(const std::vector<double>& initial_params, ObjectiveFunction objective_fn, GradientFunction gradient_fn);

    void print_params(const std::vector<double>& params);
};

#endif
