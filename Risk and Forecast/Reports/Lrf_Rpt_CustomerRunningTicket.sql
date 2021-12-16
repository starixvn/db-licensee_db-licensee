/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerRunningTicket]
(
	@AgentList VARCHAR(MAX)
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
		SELECT data.AgentId, data.Currency , e.currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
			INNER JOIN exchange e WITH(NOLOCK) ON data.currency = e.exchangeid

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS ExternalId,
			c.username SystemId, t.CurrencyName, t.TransId, t.BetType, t.Status, t.TransDate, t.WinlostDate,
			t.Stake, t.Actual_stake
	FROM 
		(
			SELECT b.custid, c.CurrCode CurrencyName, b.transid, bt.typenamee AS BetType, b.status, b.transdate, b.winlostdate,
					b.stake, b.actual_stake
			FROM @tmpAg c
				INNER JOIN bettrans b WITH (NOLOCK) ON b.recommend = c.custid
				INNER JOIN dbo.bettype bt WITH(NOLOCK) ON b.bettype = bt.typeid
			WHERE b.statusID IN (0, 1) --waiting, running
		) t
		INNER JOIN Customer c WITH(NOLOCK) ON c.CustId = t.custid and c.roleid = 1
	ORDER BY ExternalId, t.transid

END
GO
