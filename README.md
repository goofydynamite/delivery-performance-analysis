# Delivery Performance & SLA Analysis

Which shipping modes, regions and product categories have the worst on-time delivery rate, and what does lateness cost? An Indian e-commerce lens (Metro vs Tier 2 vs Tier 3 cities) on the DataCo supply-chain dataset.

**Stack:** PostgreSQL · SQL · Tableau · Python (stats)

*Work in progress: SQL pipeline, dashboard and recommendation are added in the following commits.*

## Data
DataCo Smart Supply Chain (Kaggle: `shashwatwork/dataco-smart-supply-chain-for-big-data-analysis`): 180,519 order items, 65,752 orders, Jan 2015 – Jan 2018.

The raw CSV (96 MB) is not committed. Download `DataCoSupplyChainDataset.csv` from Kaggle into `DataCo Smart Supply Chain/`.
