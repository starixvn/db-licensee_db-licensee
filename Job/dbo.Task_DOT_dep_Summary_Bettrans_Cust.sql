USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DOT_dep_Summary_Bettrans_Cust]    Script Date: 10/21/2014 17:08:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DOT_dep_Summary_Bettrans_Cust]
	@CustId       INT
	,@RecommendId INT
	,@ErrorCode   TINYINT =0 OUTPUT
AS
/*   
 Created : 20140924@Jim
 Task : Summary data for deposit member  
 DB: DBACC/bodb02  
 Revisions:   

 Param's Explanation:  

 
*/

BEGIN 
	DECLARE @minDate  			 DATETIME
			,@maxDate			 DATETIME
			,@CurrentRecommendID INT
			,@Count				 INT
					
	SELECT @minDate  = MIN(winlostdate)
		   ,@maxDate = MAX(winlostdate)
		   ,@CurrentRecommendID = MIN(recommend)
		   ,@Count   = 1 
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE CustId = @CustId
		  AND winlostdate <= DATEADD(DAY,-3,GETDATE())
	WHILE (@RecommendId <> @CurrentRecommendID)
	BEGIN
		WAITFOR DELAY '00:00:00.5'	 			
			
		SELECT  @CurrentRecommendID = recommend
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE CustId = @CustId
		
		SET @Count = @Count+1
		IF @Count = 6
		BEGIN 	
			SELECT @ErrorCode = 101	
			RETURN
		END
	END 
	
	IF (@RecommendId = @CurrentRecommendID)
	BEGIN
		WHILE (@minDate<=@maxDate)
			BEGIN
				EXEC Task_DOT_dep_DailySummary_Bettrans_Cust
					 @CustId       = @CustId
					 ,@RecommendId = @RecommendId
					 ,@RunDate     = @minDate	
				WAITFOR DELAY '00:00:00.250'	 
				SET @minDate =DATEADD(DAY,1,@minDate)
			END
	END

END
GO 
GRANT VIEW DEFINITION ON [dbo].[Task_DOT_dep_Summary_Bettrans_Cust] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Task_DOT_dep_Summary_Bettrans_Cust] TO [bodbLicenseeNet]