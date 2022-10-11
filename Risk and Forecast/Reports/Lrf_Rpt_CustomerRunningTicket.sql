/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerRunningTicket]
(
	@AgentList VARCHAR(MAX)
)
AS

/*
	Created: 20211125@Sol
	Task : Report Customer Closing Balance
	DB: DBBOF.bodb02
	Original: Lrf_Rpt_CustomerClosingBalance
  
	Revisions:
		- 20211125@Sol: Initial sp - [RedmineID: #165136]
		- 20201011@Evan: Support Currency Crypto show USDT [Redmine #177481]

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
		SELECT data.AgentId, data.Currency , CASE WHEN ExchangeId = 142 THEN 'USDT' ELSE e.currency END
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
			INNER JOIN exchange e WITH(NOLOCK) ON data.currency = e.exchangeid

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	CREATE TABLE #RunningTicket 
	(
		CustId INT, 
		CurrencyName NVARCHAR(50), 
		Refno BIGINT,
		TransId BIGINT, 
		BetType SMALLINT, 
		Status NVARCHAR(10),
		TransDate DATETIME,
		WinlostDate SMALLDATETIME,
		Stake MONEY,
		Actual_Stake MONEY
	)

	---bettrans
	INSERT INTO #RunningTicket
	(
		CustId, CurrencyName, Refno, TransId, BetType, Status, TransDate, WinlostDate, Stake, Actual_Stake
	)
	SELECT b.custid, c.CurrCode CurrencyName, b.refno, b.transid, b.BetType, b.status, b.transdate, b.winlostdate,
			b.stake, b.actual_stake
	FROM @tmpAg c
		INNER JOIN bettrans b WITH (NOLOCK) ON b.recommend = c.custid
	WHERE b.statusID IN (0, 1) --waiting, running
		AND EXISTS (SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK) WHERE b.bettype = s.bettype AND s.RefTable = 0)

	---bettransrng
	INSERT INTO #RunningTicket
	(
		CustId, CurrencyName, Refno, TransId, BetType, Status, TransDate, WinlostDate, Stake, Actual_Stake
	)
	SELECT b.custid, c.CurrCode CurrencyName, b.RefNo, b.transid, b.gameID, b.status, b.transdate, b.winlostdate,
			b.stake, b.actual_stake
	FROM @tmpAg c
		INNER JOIN dbo.bettransRnG b WITH (NOLOCK) ON b.recommend = c.custid
	WHERE b.statusID IN (0, 1) --waiting, running

	---bettranslc
	INSERT INTO #RunningTicket
	(
		CustId, CurrencyName, Refno, TransId, BetType, Status, TransDate, WinlostDate, Stake, Actual_Stake
	)
	SELECT b.custid, c.CurrCode CurrencyName, b.RefNo, b.transid, b.gameID, b.status, b.transdate, b.winlostdate,
			b.stake, b.actual_stake
	FROM @tmpAg c
		INNER JOIN dbo.bettransLC b WITH (NOLOCK) ON b.recommend = c.custid
	WHERE b.statusID IN (0, 1) --waiting, running

	---translog
	INSERT INTO #RunningTicket
	(
		CustId, CurrencyName, Refno, TransId, BetType, Status, TransDate, WinlostDate, Stake, Actual_Stake
	)
	SELECT b.custid, c.CurrCode CurrencyName, b.translogid, b.translogid, b.gameID, b.status, b.transdate, b.winlostdate,
			b.stake, b.actual_stake
	FROM @tmpAg c
		INNER JOIN dbo.translog b WITH (NOLOCK) ON b.recommend = c.custid
	WHERE b.statusID IN (0, 1) --waiting, running

	SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS ExternalId,
			c.username SystemId, t.CurrencyName, t.Refno, t.TransId, t.BetType, t.Status, t.TransDate, t.WinlostDate,
			t.Stake, t.Actual_stake
	FROM 
		(
			SELECT b.custid, b.CurrencyName, b.Refno, b.transid, bt.typenamee AS BetType, b.Status, b.transdate, b.winlostdate,
					b.stake, b.actual_stake
			FROM #RunningTicket b
				INNER JOIN dbo.bettype bt ON b.BetType = bt.typeid
		) t
		INNER JOIN Customer c WITH(NOLOCK) ON c.CustId = t.custid and c.roleid = 1
	ORDER BY ExternalId, t.transid

	DROP TABLE #RunningTicket
END
GO
