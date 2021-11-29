/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_Rpt_CustomerClosingBalance]
(
	@AgentList VARCHAR(MAX),
	@MoveBetsDay SMALLDATETIME,
	@IsNotShowCBZero BIT = 1
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
	DECLARE @tmpAg TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @tmpAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	SELECT *
	FROM 
	(
		SELECT c.custid, c.username2, c.username, c.currency, b.CurrencyName, 
			ISNULL(SUM(ISNULL(winlost,0) - ISNULL(actual_stake,0) + ISNULL(playercomm,0)),0) AS ClosingBalance
		FROM @tmpAg ag
			INNER JOIN dbo.vw_Customer c WITH(NOLOCK)
				ON ag.CustId = c.Recommend AND c.RoleId = 1
			LEFT JOIN bettrans b WITH (NOLOCK) ON b.custid = c.custid
		WHERE 1 = CASE
                    WHEN bettype = 19999 and winlostdate > @MoveBetsDay THEN 0 --> get data from ticket detail
                    WHEN bettype < 19999 and winlostdate <= @MoveBetsDay THEN 0 --> get data from sum record
                ELSE 1 END
		GROUP BY c.custid, c.username2, c.username, c.currency, b.CurrencyName
	) t
	WHERE 1 = CASE 
				WHEN @IsNotShowCBZero = 1 AND t.ClosingBalance > 0 THEN 1
				WHEN @IsNotShowCBZero = 0 THEN 1
				ELSE 0
			END
	ORDER BY t.username2
END
GO
