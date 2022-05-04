/*<info serverAlias="DBLIC-bodb_3rdProduct" executers="Dot_Member" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_GetExchangeBetDetail]
    @siteID INT,
	@version_key BIGINT=0,
	@betId BIGINT=null
AS

/*
DB: DBLIC-bodb_3rdProduct
Revisions: 
--20171127@Walter(Licensee DB) : Create for getting exchange bet detail
--20180125@Candice(Licensee DB) : remove matchAmount
--20180222@Candice(Licensee DB) : add betstatus
--20220428@Boren(Licensee DB) : add settledDate from Sum_winloss_Exchange table. (key:eventid/userid/marketid)
*/

BEGIN
	SET NOCOUNT ON
	IF @betId IS NOT NULL
	BEGIN
		set @version_key=0
		
		SELECT 
		s.settledDate,
		b.currencyType,
		b.eventType,
		b.eventTypeName,
		b.eventName,
		b.eventID,
		b.marketName,
		b.marketID,
		b.selectionName,
		b.selectionID,
		b.matchType,
		b.betID,
		b.betPlaced,
		b.ip,
		b.matchOddsReq,
		b.unMatchAmount,
		b.reduction,
		b.userId,
		b.extension1,
		b.matchStake,
		b.matchAvgOdds,
		b.profitLoss,
		b.dateMatched,
		b.betstatus,
		CONVERT(BIGINT,b.tstamp) AS version_key
	FROM [dbo].[Bettrans_Exchange] b WITH (nolock)
	LEFT JOIN [dbo].[Sum_winloss_Exchange] s WITH (nolock) 
	ON b.eventid = s.eventid AND b.userid = s.userid AND b.marketid = s.marketid
	WHERE b.betId = @betId AND b.extension1 = @siteID
	END
	ELSE
	BEGIN
	SELECT top 500
		s.settledDate,
		b.currencyType,
		b.eventType,
		b.eventTypeName,
		b.eventName,
		b.eventID,
		b.marketName,
		b.marketID,
		b.selectionName,
		b.selectionID,
		b.matchType,
		b.betID,
		b.betPlaced,
		b.ip,
		b.matchOddsReq,
		b.unMatchAmount,
		b.reduction,
		b.userId,
		b.extension1,
		b.matchStake,
		b.matchAvgOdds,
		b.profitLoss,
		b.dateMatched,
		b.betstatus,
		CONVERT(BIGINT,b.tstamp) AS version_key
	FROM [dbo].[Bettrans_Exchange] b WITH (nolock)
	LEFT JOIN [dbo].[Sum_winloss_Exchange] s WITH (nolock) 
	ON b.eventid = s.eventid AND b.userid = s.userid AND b.marketid = s.marketid
	WHERE b.tstamp > CONVERT (timestamp , @version_key ) AND b.extension1 = @siteID
	ORDER BY b.tstamp
	END
END


