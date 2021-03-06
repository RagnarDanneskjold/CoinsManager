class @BaseCrypto
  """
  Base Class for Crypto Currencies

  This class needs to be inherited by specific coins classes, and following
  methods should be overrided:

    * getValue
    * setBalance
    * getExchangeRate (TODO: not implemented yet)
  """
  api_url = "http://blockexplorer.com/q/"
  @keys = {}
  @deps =
    btc2fiat: new Deps.Dependency()
    btc2usd: new Deps.Dependency()

  constructor: (@address) ->
    # Set name for instances inheriting BaseCrypto
    @code = @constructor.code

  ensureDeps: (address, key) ->
    """Dependencies are set to class attributes, to be retrievable anywhere"""
    if not BaseCrypto.deps[@name]
      BaseCrypto.deps[@name] = {}
    if not BaseCrypto.deps[@name][address]
      BaseCrypto.deps[@name][address] = {}
    if not BaseCrypto.keys[@name]
      BaseCrypto.keys[@name] = {}
    if not BaseCrypto.keys[@name][address]
      BaseCrypto.keys[@name][address] = {}
    if not BaseCrypto.deps[@name][address][key]
      BaseCrypto.deps[@name][address][key] = new Deps.Dependency()
      if key is "balance" then @setBalance()

  getBalance: ->
    """Retrieve value set from @setBalance()"""
    @ensureDeps @address, "balance"
    BaseCrypto.deps[@name][@address].balance.depend()
    return BaseCrypto.keys[@name][@address].balance

  get_name: ->
    if @name then @name else @constructor.name

  getValue: (withUSD=false) ->
    """
    Override this method from a specific coin class, to calculate the value of
    an address using the balance and exchange rate.
    Should look like this:

      getValue: ->
        balance = @getBalance()
        rate = @getExchangeRate()
        return balance * rate

    """
    @ensureDeps @address, "value"
    # Value depends in on the "coin2btc" value and "btc2fiat" value
    BaseCrypto.deps[@name][@address].value.depend()
    BaseCrypto.deps.btc2fiat.depend()

    result = undefined
    if _.isNumber BaseCrypto.keys[@name][@address].value
      value = BaseCrypto.keys[@name][@address].value
      if withUSD is true
        btc2fiat = BaseCrypto.keys.btc2usd
      else
        btc2fiat = BaseCrypto.keys.btc2fiat

      result = value * @getBalance() * btc2fiat
    else if BaseCrypto.keys[@name][@address].total_value?
      # For non-implemented coins
      result = BaseCrypto.keys[@name][@address].total_value
    if result?
      return result.toFixed 2

  setBalance: (url, lambda_balance) ->
    """
    create a method with the same name but without arguments in the coin class.
    Method should look like this:

      setBalance: ->
        url = @api_url + @address
        super url, @lambda_balance

    """
    cls = @

    Meteor.call "callUrl", url, (err, result) ->
      if err
        throw new Meteor.Error err.error, err.reason
      else
        value = lambda_balance result
        if isNaN value
          return
        BaseCrypto.keys[cls.name][cls.address].balance = value
        BaseCrypto.deps[cls.name][cls.address].balance.changed()

  @getAddressFormat: (address) ->
    """
    Returns the address format, or an error if address is not valid
    """
    result = Meteor.call "callUrl", "#{api_url}checkaddress/#{address}"
    switch result.content
      when "X5" then throw new Meteor.Error 601, "Address not base58"
      when "CK" then throw new Meteor.Error 603, "Failed hash check"
      when "SZ"
      then throw new Meteor.Error 602, "Address not the correct size"
      else result.content
