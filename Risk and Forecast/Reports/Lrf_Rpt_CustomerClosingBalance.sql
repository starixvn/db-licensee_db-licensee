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
		- 20220121@Sol: Split Transfer out of bettrans/Support IPv6 - [RedmineID: #164301]
		- 20201011@Evan: Support Currency Crypto show USDT [Redmine #177481]
	Param's Explanation:
		- @AgentList: list agent of licensee
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	DECLARE @tmpAg TABLE (CustId INT, Currency INT, CurrCode NVARCHAR(50))
	DECLARE @DocHandler INT

	CREATE TABLE #ClosingBalance(CustId INT, CurrName NVARCHAR(50), ClosingBalance MONEY)
	CREATE TABLE #RunningCust(CustId INT, CurrName NVARCHAR(50))

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @tmpAg(CustId, Currency, CurrCode)
		SELECT data.AgentId, data.Currency, CASE WHEN ExchangeId = 142 THEN 'USDT' ELSE e.currency END
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

		---from bettrans
		INSERT INTO #ClosingBalance(CustId, CurrName, ClosingBalance)
		SELECT b.custid, c.CurrCode AS CurrencyName,
				ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
		FROM @tmpAg c
			INNER JOIN bettrans b WITH (NOLOCK) ON b.recommend = c.custid
		WHERE b.bettype < 19999 AND b.winlostdate > @MoveBetsDay
		GROUP BY b.custid, c.CurrCode

		---from transfer
		INSERT INTO #ClosingBalance(CustId, CurrName, ClosingBalance)
		SELECT t.custid, c.CurrCode AS CurrencyName,
				ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
		FROM @tmpAg c
			INNER JOIN dbo.Transfer t WITH (NOLOCK) ON t.recommend = c.custid
		WHERE (t.bettype = 19999 AND t.winlostdate <= @MoveBetsDay OR t.Bettype > 19999)
		GROUP BY t.custid, c.CurrCode

		SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS ExternalId , c.Username AS SystemId, t.CurrencyName, t.ClosingBalance
		FROM 
			(
				SELECT t.custid, t.CurrName AS CurrencyName, ISNULL(SUM(t.ClosingBalance),0) AS ClosingBalance
				FROM #ClosingBalance t
				GROUP BY t.custid, t.CurrName
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
			SELECT DISTINCT b.custid, c.CurrCode
			FROM @tmpAg c
				INNER JOIN bettrans b WITH (NOLOCK) ON b.recommend = c.custid
			WHERE b.statusID IN (0, 1) --waiting, running
			UNION
			SELECT DISTINCT b.custid, c.CurrCode
			FROM @tmpAg c
				INNER JOIN dbo.translog b WITH (NOLOCK) ON b.recommend = c.custid
			WHERE b.statusID IN (0, 1) --waiting, running
		)
		INSERT INTO #RunningCust(CustId, CurrName)
		SELECT c.custid, c.CurrCode
		FROM CustHasRunningTicket c

		---from bettrans
		INSERT INTO #ClosingBalance(CustId, CurrName, ClosingBalance)
		SELECT b.custid, r.CurrName AS CurrencyName,
				ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
		FROM bettrans b WITH (NOLOCK) 
			INNER JOIN #RunningCust r
				ON b.custid = r.custid
		WHERE b.bettype < 19999 AND b.winlostdate > @MoveBetsDay
		GROUP BY b.custid, r.CurrName

		---from transfer
		INSERT INTO #ClosingBalance(CustId, CurrName, ClosingBalance)
		SELECT t.custid, r.CurrName AS CurrencyName,
				ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
		FROM dbo.Transfer t WITH (NOLOCK) 
			INNER JOIN #RunningCust r
				ON t.custid = r.custid
		WHERE (t.bettype = 19999 AND t.winlostdate <= @MoveBetsDay OR t.Bettype > 19999)
		GROUP BY t.custid, r.CurrName

		SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS ExternalId , c.Username AS SystemId, t.CurrencyName, t.ClosingBalance
		FROM 
			(
				SELECT t.custid, t.CurrName AS CurrencyName,
					ISNULL(SUM(t.ClosingBalance),0) AS ClosingBalance
				FROM #ClosingBalance t
				GROUP BY t.custid, t.CurrName
			) t
			INNER JOIN Customer c WITH(NOLOCK) ON c.CustId = t.custid and c.roleid = 1
		ORDER BY ExternalId

	END

	DROP TABLE #ClosingBalance
	DROP TABLE #RunningCust

END
GO
