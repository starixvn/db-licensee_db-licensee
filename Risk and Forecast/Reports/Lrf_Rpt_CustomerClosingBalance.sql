/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerClosingBalance]
(
	@AgentList VARCHAR(MAX),
	@MoveBetsDay SMALLDATETIME,
	@ReportType TINYINT = 1
)
AS

/*
	Created: 20211125@Sol
	Task : Report Customer Closing Balance
	DB: DBACC.bodb02
	Original: Lrf_Rpt_CustomerClosingBalance
  
	Revisions:
		- 20211125@Sol: Initial sp - [RedmineID: #165136]

	Param's Explanation:
		- @AgentList: list agent of licensee
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	DECLARE @tmpAg TABLE (CustId INT, Currency INT, CurrCode NVARCHAR(50))
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @tmpAg(CustId, Currency, CurrCode)
		SELECT data.AgentId, data.Currency, e.currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
			INNER JOIN exchange e WITH(NOLOCK) ON data.currency = e.exchangeid

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	IF (@ReportType = 1)
	BEGIN
		SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS ExternalId , c.Username AS SystemId, t.CurrencyName, t.ClosingBalance
		FROM 
			(
				SELECT b.custid, c.CurrCode AS CurrencyName,
					ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
				FROM @tmpAg c
					INNER JOIN bettrans b WITH (NOLOCK) ON b.recommend = c.custid
				WHERE 1 = CASE
							WHEN bettype = 19999 and winlostdate > @MoveBetsDay THEN 0 --> get data from ticket detail
							WHEN bettype < 19999 and winlostdate <= @MoveBetsDay THEN 0 --> get data from sum record
						ELSE 1 END
				GROUP BY b.custid, c.CurrCode
			) t
			INNER JOIN Customer c WITH(NOLOCK) ON c.CustId = t.custid and c.roleid = 1
		WHERE t.ClosingBalance > 0
		ORDER BY ExternalId
	END
	ELSE 
	BEGIN
		-- get running custid
		;WITH CustHasRunningTicket AS
		(
			SELECT b.custid, c.CurrCode
			FROM @tmpAg c
				INNER JOIN bettrans b WITH (NOLOCK) ON b.recommend = c.custid
			WHERE b.statusID IN (0, 1) --waiting, running
		)
		SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS ExternalId , c.Username AS SystemId, t.CurrencyName, t.ClosingBalance
		FROM 
			(
				SELECT b.custid, r.CurrCode AS CurrencyName,
					ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
				FROM bettrans b WITH (NOLOCK) 
					INNER JOIN CustHasRunningTicket r
						ON b.custid = r.custid
				WHERE 1 = CASE
							WHEN bettype = 19999 and winlostdate > @MoveBetsDay THEN 0 --> get data from ticket detail
							WHEN bettype < 19999 and winlostdate <= @MoveBetsDay THEN 0 --> get data from sum record
						ELSE 1 END
				GROUP BY b.custid, r.CurrCode
			) t
			INNER JOIN Customer c WITH(NOLOCK) ON c.CustId = t.custid and c.roleid = 1
		ORDER BY ExternalId

	END

END
GO
