/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_LicenseeBaseCurrencySel]
	@LicenseeId	INT
AS 
/*

	Created: 20190517@Amanda
	Task : Get base currency of Licensee used for billing
	DB: DBLIC/bodb_Licensee

	Revisions:
		- 20190517@Amanda: Create SP [RedmineID: #112173]

*/
BEGIN
	SET NOCOUNT ON

	SELECT TOP 1 
		CASE e.exchangeid
			WHEN 20 THEN 'UUS' 
			WHEN 51 THEN 'INH'
			WHEN 70 THEN 'MKK'
			WHEN 75 THEN 'PTU'
			WHEN 76 THEN 'PS'
			WHEN 77 THEN 'PTH'
			ELSE e.Code
		END
		AS 'BaseCurrency'
	FROM dbo.OAS_Party p WITH (NOLOCK)
	INNER JOIN dbo.OAS_PartyDetail d WITH (NOLOCK) ON p.PartyID = d.PartyID
	INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON d.BaseCurrencyId = e.exchangeid
	WHERE p.PartyType = 1 -- Payer
		AND p.OldRefID = @LicenseeId
END
GO