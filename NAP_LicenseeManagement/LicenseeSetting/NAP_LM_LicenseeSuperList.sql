/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap,wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseeSuperList] 
	@Site		 NVARCHAR(50)
	,@DeniedList NVARCHAR(MAX)=NULL
AS
/*
	Created: Elodie
	Date: 20150129
	Task : Licensee Setting Configuration - Get a list of Licensee super  [#6304]
	DB: DBCUST.CustDB
	Original:

	Revisions:
		- 20150609@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)
		- 20230224@Winfred: NAP LM - Enhance Bet Setting function for AM to use [redmine:#178105]
		- 20230629@Winfred: NAP LM - PRO - Licensee Bet Setting - Currency filter has not taken data according to Currency Code [redmine:#190436]
		- 20240522@Tacy: NAP - Permission controls on real currency [redmineID: #202523]
		- 20240805@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]

	Param's Explanation:
	Example:
		EXEC NAP_LM_LicenseeSuperList @Site = '12BET'
*/ 
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpExchange TABLE (exchangeID INT, Currency NVARCHAR(50), OfferSite TINYINT)

	IF ISNULL(@DeniedList,'')<>''
	BEGIN
		--get deny currency
		INSERT INTO  @tmpExchange (exchangeID, Currency, OfferSite)
		SELECT vl.[ID], vl.[Name], vl.[Opt]
		FROM OPENJSON(@DeniedList) 
				WITH (  [KeyName]	VARCHAR(30),
						[Value]	NVARCHAR(MAX) AS JSON
					) AS js
		CROSS APPLY OPENJSON (js.[value])
				WITH (  [ID]	INT,
						[Name]	NVARCHAR(30),
						[Opt]	TINYINT
					) AS vl
		WHERE js.[KeyName]='Exchange'
	END

	SELECT s.custid, s.username, e.currency, e.ExchangeId, e.Code AS CurrencyCode
	FROM dbo.Dep_CustSuper AS s WITH (NOLOCK)
		INNER JOIN exchange e WITH(NOLOCK) ON s.currency = e.ExchangeId
	WHERE s.site = @Site
	AND e.ExchangeId NOT IN (SELECT ExchangeId FROM @tmpExchange)
	ORDER BY e.currency 
END

