/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CurrencySel]
AS

/*
	Created: 20191021@Amanda
	Description: LAP - Get All Currency Info
	DB: DBEXT.bodb02

	Revisions:
		- 20191021@Amanda: Add new SP [Redmine: #120333]
		- 20200220@Louis: Cheat currency name for HID Currency [RedmineID: #128816]
		- 20211006@Howard: New China View Skin, hard code INH2 Currency [RedmineID: #161966]
		- 20221010@Kos: Support crypto currency [Redmine: 177481]
		- 20230208@Kai: Hard code USDTJP, USDT currency [Redmine: 183455]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		ExchangeId AS Id,
		CASE
			WHEN ExchangeId = 20 THEN 'UUS'
			WHEN ExchangeId = 51 THEN 'INH'
			WHEN ExchangeId = 70 THEN 'MKK'
			WHEN ExchangeId = 75 THEN 'PTU'
			WHEN ExchangeId = 76 THEN 'PS'
			WHEN ExchangeId = 77 THEN 'PTH'
			WHEN ExchangeId = 92 THEN 'HID'
			WHEN ExchangeId = 96 THEN 'USDT'
			WHEN ExchangeId = 125 THEN 'INH'
			WHEN ExchangeId = 202 THEN 'USDTJP'
			-- crypto currencies
			WHEN ExchangeId = 142 THEN 'USDT'
			WHEN CurrencyType = 1 THEN currency		
			ELSE Code
		END AS Name
	FROM dbo.Exchange WITH (NOLOCK)
END
GO
