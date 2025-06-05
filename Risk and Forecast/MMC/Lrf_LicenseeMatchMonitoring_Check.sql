/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoring_Check]
    @LicenseeId		INT,
    @MatchID		INT,
    @BetType		SMALLINT,
    @LiveHomeScore	SMALLINT = NULL,
    @LiveAwayScore	SMALLINT = NULL,
    @LiveIndicator	BIT = 0,
	@Langkey		VARCHAR(20)	= 'en-US',
    @ErrCode		INT = 0 OUTPUT,
    @ErrMsg			NVARCHAR(500) = NULL OUTPUT
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Match Monitoring Center
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]

    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
      -- Initialize
    SET @ErrCode = 0
    SET @ErrMsg = NULL

    -- Check Licensee exists and active
    IF NOT EXISTS (
        SELECT 1 
        FROM [dbo].[Licensees] WITH(NOLOCK)  
        WHERE LicenseeID = @LicenseeId 
        AND IsActive = 1
    )
    BEGIN
        SET @ErrCode = 91        
		SET @ErrMsg = CASE WHEN @Langkey='en-US'
							THEN 'This Licensee does not exists!'
							ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200021, @Langkey)
						END
        RETURN 
    END    
	
	-- Check Match already monitored
    IF EXISTS (
        SELECT 1 
        FROM [dbo].[LicenseeMatchMonitoring] WITH(NOLOCK)
        WHERE LicenseeId = @LicenseeId 
        AND MatchID = @MatchID
        AND BetType = @BetType
		AND LiveIndicator=@LiveIndicator
		AND ISNULL(LiveHomeScore,0)=ISNULL(@LiveHomeScore,0)
		AND ISNULL(LiveAwayScore,0)=ISNULL(@LiveAwayScore,0)
        AND IsActive = 1
    )
    BEGIN
        SET @ErrCode = 92        
		SET @ErrMsg =  CASE WHEN @Langkey='en-US'
							THEN 'This event has already been added to the monitoring list.'
							ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200052, @Langkey)
						END
        RETURN
    END

    -- Check Live Scores validity
    IF @LiveIndicator = 0 
    AND (ISNULL(@LiveHomeScore, 0) > 0 OR ISNULL(@LiveAwayScore, 0) > 0)
    BEGIN
        SET @ErrCode = 93
        SET @ErrMsg = 'Live scores cannot be set for non-live matches.'
        RETURN
    END

    RETURN
END
GO
