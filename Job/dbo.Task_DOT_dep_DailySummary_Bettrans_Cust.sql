ALTER PROCEDURE [dbo].[Task_DOT_dep_DailySummary_Bettrans_Cust]
	@CustId		  INT
	,@RecommendId INT
	,@RunDate	  DATETIME
AS
/*   
 Created : 20140924@Jim
 Task : Summary data for deposit member  
 DB: DBACC/bodb02  
 Revisions:   

 Param's Explanation:  

 
*/
BEGIN
	UPDATE dbo.rptDepWinlost WITH (ROWLOCK,UPDLOCK)
	SET recommend = @RecommendId
	WHERE CustID = @CustId
		AND winlostdate = @RunDate

	UPDATE 	dbo.rptDepwinlost_SUM WITH (ROWLOCK,UPDLOCK)
	SET recommend = @RecommendId
	WHERE CustID = @CustId
		AND winlostdate = @RunDate
	UPDATE dbo.rptDepWinlost_Transfer3rdOthers WITH (ROWLOCK,UPDLOCK)	
	SET recommend = @RecommendId
	WHERE CustID = @CustId
		AND winlostdate = @RunDate
END
	
GO 
GRANT VIEW DEFINITION ON [dbo].[Task_DOT_dep_DailySummary_Bettrans_Cust] TO [vnteam]