/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelCurrencyByLicenseeUser]
	@LicenseeId	INT = 0,
	@UserId		INT
AS

/*
	Created: 20130509@Jim
	Task: Restrict permission of Licensee Users by currency
	DB: DBEXT.bodb02

	Revisions:
		- 20141118@winnie: Change from LicenseeCust table to f_SelLicenseeCust
		- 20160413@Victor: support MKK currency code
		- 20160523@Jim: Currency permision restrict (#53882)
		- 20170216@Sophia: Get AgentID, cast isActive as BIT, remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Cheat currency name for special currencies [RedmineID: #94845]
		- 20200220@Louis: Cheat currency name for HID Currency [RedmineID: #128816]
		- 20211006@Howard: New China View Skin, hard code INH2 Currency [RedmineID: #161966]
		- 20221010@Kos: Support crypto currency [Redmine: 177481]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Currency TABLE (CurrencyId INT, LicenseeId INT)

	INSERT INTO @Currency (CurrencyId, LicenseeId)
	SELECT CurrencyID, LicenseeID
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)-- System is default=1 (LRF)
	WHERE currencyID NOT IN (SELECT CurrencyID FROM bodb_licensee.dbo.Lrf_f_LicenseeCurrencyLimit () WHERE LicenseeID = @LicenseeId)

	SELECT DISTINCT
		lc.Currency,
		CASE
			WHEN lc.currency = 20 THEN 'UUS'
			WHEN lc.currency = 51 THEN 'INH'
			WHEN lc.currency = 70 THEN 'MKK'
			WHEN lc.currency = 75 THEN 'PTU'
			WHEN lc.currency = 76 THEN 'PS'
			WHEN lc.currency = 77 THEN 'PTH'
			WHEN lc.currency = 92 THEN 'HID'
			WHEN lc.currency = 125 THEN 'INH'
			-- crypto currencies
			WHEN lc.currency = 142 THEN 'USDT'
			WHEN e.CurrencyType = 1 THEN e.currency
			ELSE e.Code
		END AS CurrencyName,
		CASE WHEN ISNULL(c.CurrencyID, 0) = 0 THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END IsActive,
		lc.CustID AS AgentId
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@LicenseeID) AS lc
		LEFT JOIN @Currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
		INNER JOIN exchange e with (nolock) ON lc.currency = e.exchangeid
	WHERE @LicenseeId = 0 OR lc.LicenseeID = @LicenseeId
	ORDER BY
		CASE
			WHEN lc.currency = 20 THEN 'UUS'
			WHEN lc.currency = 51 THEN 'INH'
			WHEN lc.currency = 70 THEN 'MKK'
			WHEN lc.currency = 75 THEN 'PTU'
			WHEN lc.currency = 76 THEN 'PS'
			WHEN lc.currency = 77 THEN 'PTH'
			WHEN lc.currency = 92 THEN 'HID'
			WHEN lc.currency = 125 THEN 'INH'
			-- crypto currencies
			WHEN lc.currency = 142 THEN 'USDT'
			WHEN e.CurrencyType = 1 THEN e.currency
			ELSE e.Code
		END
END
GO
