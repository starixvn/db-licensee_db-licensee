/*<info serverAlias="DBLIC-bodb_3rdProduct" executers="Dot_Member" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_GetExchange_M_BetDetail]
	  @betId BIGINT
AS
/*
DB: DBLIC-bodb_3rdProduct
Revisions:
--20171128@Candice(DB052.bodb_3rdProduct) : Create for getting exchange M bet detail
--20180125@Candice(DB052.bodb_3rdProduct) : remove matchAmount
--20230915@Boren(DB052.bodb_3rdProduct) : remove TransID, betTaken, txStake, txOddsMatched, actualOdds; add txFancyBetRuns.
*/

BEGIN
	SET NOCOUNT ON
	SELECT [betID]
		 , [txFancyBetRuns]
	FROM [bodb_3rdProduct].[dbo].[BettransM_Exchange] WITH (NOLOCK)
	WHERE [betID] = @betId
END