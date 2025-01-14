# WHAM example 3: projections
# Replicate Miller et al 2016 results
#   adds environmental covariate (CPI, treated as rw)
#   uses 5 indices (ex 1: only 2 indices)
#   only fit to 1973-2011 data (ex 1: 1973-2016)
#   age compositions = 5, logistic normal pool zero obs (ex 1: 7, logistic normal missing zero obs)
#   selectivity = logistic (ex 1: age-specific)

# btime <- Sys.time(); devtools::test("/home/bstock/Documents/wham"); etime <- Sys.time(); runtime = etime - btime;
# btime <- Sys.time(); testthat::test_file("/home/bstock/Documents/wham/tests/testthat/test_ex3_projections.R"); etime <- Sys.time(); runtime = etime - btime;
# 5.7 min

context("Ex 3: Projections")

test_that("Ex 3 works",{
# get results to check NLL and par estimates
path_to_examples <- system.file("extdata", package="wham")
# ex3_test_results <- readRDS(file.path(path_to_examples,"ex3_test_results.rds"))

asap3 <- read_asap3_dat(file.path(path_to_examples,"ex2_SNEMAYT.dat"))
env.dat <- read.csv(file.path(path_to_examples,"CPI.csv"), header=T)

# specify model: AR1 CPI, limiting effect on Bev-Holt
env <- list(
  label = "CPI",
  mean = as.matrix(env.dat$CPI), # CPI observations
  sigma = as.matrix(env.dat$CPI_sigma), # CPI standard error is given/fixed as data
  year = env.dat$Year,
  use_obs = matrix(1, ncol=1, nrow=dim(env.dat)[1]), # use all obs (=1)
  lag = 1, # CPI in year t affects recruitment in year t+1
  process_model = "ar1", # fit CPI as AR1 process
  where = "recruit", # CPI affects recruitment
  how = 1) # controlling (dens-indep mortality)

input <- prepare_wham_input(asap3, recruit_model = 3,
                            model_name = "Ex 3: Projections",
                            Ecov = env,
                            selectivity=list(model=rep("logistic",6),
                                             initial_pars=c(rep(list(c(3,3)),4), list(c(1.5,0.1), c(1.5,0.1))),
                                             fix_pars=c(rep(list(NULL),4), list(1:2, 1:2))))

# age comp logistic normal pool obs (not multinomial, the default)
input$data$age_comp_model_fleets = rep(5, input$data$n_fleets) # 1 = multinomial (default), 5 = logistic normal (pool zero obs)
input$data$n_age_comp_pars_fleets = c(0,1,1,3,1,2)[input$data$age_comp_model_fleets]
input$data$age_comp_model_indices = rep(5, input$data$n_indices) # 1 = multinomial (default), 5 = logistic normal (pool zero obs)
input$data$n_age_comp_pars_indices = c(0,1,1,3,1,2)[input$data$age_comp_model_indices]
n_catch_acomp_pars = c(0,1,1,3,1,2)[input$data$age_comp_model_fleets[which(apply(input$data$use_catch_paa,2,sum)>0)]]
n_index_acomp_pars = c(0,1,1,3,1,2)[input$data$age_comp_model_indices[which(apply(input$data$use_index_paa,2,sum)>0)]]
input$par$catch_paa_pars = rep(0, sum(n_catch_acomp_pars))
input$par$index_paa_pars = rep(0, sum(n_index_acomp_pars))

# full state-space model, abundance is the state vector
input$data$use_NAA_re = 1
input$data$random_recruitment = 0
input$map = input$map[!(names(input$map) %in% c("log_NAA", "log_NAA_sigma", "mean_rec_pars"))]
input$map$log_R = factor(rep(NA, length(input$par$log_R)))
input$random = c(input$random, "log_NAA","Ecov_re")

# ---------------------------------------------------------
## Fit model without projections
mod <- fit_wham(input, do.proj=FALSE)
# saveRDS(mod, file="m6.rds")
# mod <- readRDS("/home/bstock/Documents/wham/sandbox/ex3_projections/m6.rds")

# Add projections to previously fit model
mod_proj <- list()

# default settings: 3 years, use last F, continue Ecov
mod_proj[[1]] <- project_wham(mod, proj.opts=list(n.yrs=3, use.last.F=TRUE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=TRUE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# 5 years, use last F, average Ecov 1992-1996
mod_proj[[2]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=TRUE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=FALSE, use.last.Ecov=FALSE, avg.Ecov.yrs=1992:1996, proj.Ecov=NULL))

# 5 years, use last F, use last Ecov
mod_proj[[3]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=TRUE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=FALSE, use.last.Ecov=TRUE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# 5 years, use last F, specify high CPI ~ 0.5
mod_proj[[4]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=TRUE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=FALSE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=matrix(c(0.5,0.7,0.4,0.5),ncol=1)))

# 5 years, use last F, specify low CPI ~ -1.5
mod_proj[[5]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=TRUE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=FALSE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=matrix(c(-1.6,-1.3,-1,-1.2),ncol=1)))

# specify catch, 5 years
mod_proj[[6]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=FALSE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=c(10, 2000, 1000, 3000, 20), avg.yrs=NULL,
              cont.Ecov=TRUE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# specify F, 5 years
mod_proj[[7]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=FALSE, use.avg.F=FALSE,
              use.FXSPR=FALSE, proj.F=c(0.001, 1, 0.5, .1, .2), proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=TRUE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# use FXSPR (avg.yrs defaults to last 5 years, 2007-2011), 5 years
mod_proj[[8]] <- project_wham(mod, proj.opts=list(n.yrs=5, use.last.F=FALSE, use.avg.F=FALSE,
              use.FXSPR=TRUE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=TRUE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# use avg F (avg.yrs defaults to last 5 years, 2007-2011), 3 years
mod_proj[[9]] <- project_wham(mod, proj.opts=list(n.yrs=3, use.last.F=FALSE, use.avg.F=TRUE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=NULL,
              cont.Ecov=TRUE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# use avg F 1992-1996, 10 years
mod_proj[[10]] <- project_wham(mod, proj.opts=list(n.yrs=10, use.last.F=FALSE, use.avg.F=TRUE,
              use.FXSPR=FALSE, proj.F=NULL, proj.catch=NULL, avg.yrs=1992:1996,
              cont.Ecov=TRUE, use.last.Ecov=FALSE, avg.Ecov.yrs=NULL, proj.Ecov=NULL))

# saveRDS(mod_proj, file="m6_proj.rds")
# mod_proj <- readRDS("/home/bstock/Documents/wham/sandbox/ex3_projections/m6_proj.rds")

#  check marginal nll is the same
nll_proj <-  sapply(mod_proj, function(x) x$opt$obj)
# mod$opt$obj


# plot results
tmp.dir <- tempdir(check=TRUE)
for(m in 1:length(mod_proj)){
  plot_wham_output(mod_proj[[m]], dir.main=tmp.dir, out.type='html')
  expect_equal(nll_proj[m], as.numeric(mod$opt$obj), tolerance=1e-6)
  expect_equal(as.numeric(mod_proj[[m]]$opt$par), as.numeric(mod$opt$par), tolerance=1e-3) # parameter values
}

})

# # remove files created during testing
# teardown(unlink(tmp.dir, recursive=TRUE))
