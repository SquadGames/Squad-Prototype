# Squad (Consider the name Squad Platform)

Decentralized marketplace for cooperative content

## Developing

* Run tests with `npm test`
* Run the full CI suite with `npm run ci`
* Run `npx standard --fix` to pass the linting in the CI suite

## Outline

* Smart contract system
  * Create bonds associated to content
  * Automatically purchase a basket of bonds with surplus from another
  * Set of default curves
  * Revenue sharing implementations
  * Other supporting contracts (purchase reciepts)
* Contribution and license datastore
* SDKs (in various languages)
  * Configurable by:
    * Contribution schema
    * Allowed licenses
    * Market options
  * UX components
  * Purchase/ownership confirmation
  * Possibly fiat on/off ramp services
