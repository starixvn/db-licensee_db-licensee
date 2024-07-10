/*<info serverAlias="DBLIC-bodb_3rdProduct" executers="svc_tig" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_GetExchangeBetDetail]
	  @siteID INT
	, @version_key BIGINT = 0
	, @betId BIGINT = NULL
	, @betPlaced DATETIME = NULL
AS
/*
DB: DBLIC-bodb_3rdProduct
Revisions:
--20171127@Walter(Licensee DB) : Create for getting exchange bet detail
--20180125@Candice(Licensee DB) : remove matchAmount
--20180222@Candice(Licensee DB) : add betstatus
--20220428@Boren(Licensee DB) : add settledDate & resettledDate from Sum_winloss_Exchange table. (key:eventid/userid/marketid)
--20230915@Boren(Licensee DB) : remove select eventtype, extension1, unMatchAmount, reduction, add fancyBetRuns.
--20230920@Boren(Licensee DB) : add @betPlaced.
--20240710@Alex.Kan(Licensee DB) : improve performance
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @version_key_min BIGINT = 0
		  , @tstamp TIMESTAMP
		  , @extension1 CHAR(7);

	IF @version_key = 0
	BEGIN
		SELECT @version_key_min = CONVERT(BIGINT, MIN(b.tstamp))
		FROM [dbo].[Bettrans_Exchange] b WITH (NOLOCK)
		WHERE b.betPlaced >= @betPlaced
			
		SELECT @version_key = ISNULL(@version_key_min, 1) - 1
	END
	
	SELECT @tstamp = CONVERT(TIMESTAMP, @version_key)
		 , @extension1 = CONVERT(CHAR(7), @siteID)
	
	IF @betId IS NOT NULL
	BEGIN
		SET @version_key = 0
		SELECT s.settledDate
			 , s.resettledDate
			 , b.currencyType
			 , b.eventTypeName
			 , b.eventName
			 , b.eventID
			 , b.marketName
			 , b.marketID
			 , b.selectionName
			 , b.selectionID
			 , b.matchType
			 , b.betid
			 , b.betPlaced
			 , b.ip
			 , b.matchOddsReq
			 , b.userId
			 , b.matchStake
			 , b.matchAvgOdds
			 , b.profitLoss
			 , b.betstatus
			 , b.fancyBetRuns
			 , CONVERT(BIGINT, b.tstamp) AS version_key
		FROM [dbo].[Bettrans_Exchange] b WITH (NOLOCK)
			LEFT JOIN [dbo].[Sum_winloss_Exchange] s WITH (NOLOCK) ON b.eventid = s.eventid
				AND b.userid = s.userid
				AND b.marketid = s.marketid
		WHERE b.betid = @betId
			AND b.extension1 = @extension1
	END
	ELSE
	BEGIN
		SELECT TOP 500 s.settledDate
					 , s.resettledDate
					 , b.currencyType
					 , b.eventTypeName
					 , b.eventName
					 , b.eventID
					 , b.marketName
					 , b.marketID
					 , b.selectionName
					 , b.selectionID
					 , b.matchType
					 , b.betid
					 , b.betPlaced
					 , b.ip
					 , b.matchOddsReq
					 , b.userId
					 , b.matchStake
					 , b.matchAvgOdds
					 , b.profitLoss
					 , b.betstatus
					 , b.fancyBetRuns
					 , CONVERT(BIGINT, b.tstamp) AS version_key
		FROM [dbo].[Bettrans_Exchange] b WITH (NOLOCK)
			LEFT JOIN [dbo].[Sum_winloss_Exchange] s WITH (NOLOCK) ON b.eventid = s.eventid
				AND b.userid = s.userid
				AND b.marketid = s.marketid
		WHERE b.tstamp > @tstamp
			AND b.extension1 = @extension1
		ORDER BY b.tstamp
	END
END

GO
