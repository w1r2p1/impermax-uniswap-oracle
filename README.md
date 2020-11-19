# Impermax Uniswap Oracle
> **Note:** this project has never been properly tested and therefore should be considered a work in progress.

The Impermax Uniswap Oracle is a price oracle based on Uniswap TWAP that allow users to retrieve the moving average of the price of a specific pair on uniswap for certains **time intervals**. 
Each time interval is defined by a minimum and a maximum boundaries (Kmin and Kmax). When calculating the price of a pair for a certain time interval, the Impermax Uniswap Oracle will return either:

 - The moving average of the price for the last X seconds, where Kmin <= X <= Kmin + Kmax, if the price can be calculated for that pair. This mean that the price will be the result of the average  of the last Kmin seconds at least, and Kmin + Kmax seconds at most.
 - An error signal if the price could not be calculated for that pair.

For each time interval at any given point in time the price can either be calculated or not. Generally speaking, the price for a certain time interval can always be calculated as long as there is at least an update every Kmax seconds.
The price on the oracle is updated for each time interval for a certain pair every time that a call is made to the contract to calculate the price for that pair in any time interval. This mean that the oracle will work better and will be always updated when it is used more.

In the current implementation the oracle is working on **5 time intervals**:
| Kmin | Kmax | X belongs to | Price must be updated every
|--|--|--|--|
| 4' | 12' | [4', 16'] | 12' |
| 12' | 36' | [12', 48'] | 36' |
| 36' | 1h48' | [36', 2h24'] | 1h48' |
| 1h48' | 5h24' | [1h48', 7h12'] | 5h24' |
| 5h24' | 16h12' | [5h24', 21h36'] | 16h12' |

Where the price calculated for the time interval equals to MovingAverage(X)

**The main problem for price oracle based on TWAP is keeping the price updated**. We suggest the read of the article [Using Uniswap V2 Oracle With Storage Proofs](https://medium.com/@epheph/using-uniswap-v2-oracle-with-storage-proofs-3530e699e1d3) for a better understanding of the problem. In a few words, the are two ways for keeping the price updated:

 1. Making frequent updates. This is the only strategy on which this implementation rely. If a price is not updated for a time interval, than a user of the oracle who wants to make that price available again should update the price, wait at least Kmin (but not more then Kmax) seconds and update the price again. Once a price is up to date it will stay updated as long as there is un update at least every Kmax seconds. Notice that for the firsts time intervals the price will be fresher, but it will also require more frequent updates. At the same time if a price is not up to date, the amount of time that is needed to be waited in order to make the price available again for small time intervals will be much lower then for large time intervals. This first approach has a relatively low cost of around 50k gas per update.
 2. Using Ethereum storage proofs. This approach allows to make the price up to date instantly for time intervals with Kmin < 1 hour, while being more costly in terms of gas. Another implementation of this oracle with the addition of storage proofs can be found [here](https://github.com/Impermax-Finance/impermax-uniswap-oracle-storage-proof-contracts)
