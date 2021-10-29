# WTF

This is a small program that will apply Monte Carlo trials to stock prices using geometric Brownian motion with constant (and in a future version local or stochastic) dispersion.

## Rationale

If you're writing options on the market, you want to know whether your strikes will hold.  Rather than divine it based on which side of the lawn your dog decides to shit on, we can accept that the market's movements are stochastic in nature and we can use the power of statistics to glean some insights as to what are the likely vs unlikely outcomes when our FD's expire on Friday.

## Can't you just look at Delta?

You could, but the delta that you get from the BSM model does not include a drift term.  So in a momentum market, Black-Scholes will underestimate the probability of OTM call options expiriing in the money, and overestimate the same for puts.

## Disclaimer

I learned this stuff mostly from talking to my wife's boyfriend, you should do your own due diligence, not financial advice, etc.
