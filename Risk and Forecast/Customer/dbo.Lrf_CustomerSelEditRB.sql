ALTER PROCEDURE [dbo].[Lrf_CustomerSelEditRB]
	@custid INT
AS
/*
Created: 20110331@Henry
Task : Get Racebook information
DB: DB052.bodb02
	20120326@Dom: change CustSetting3rd to Dep_CustSetting3rd
Revisions:
   
Param's Explanation:

*/
SET NOCOUNT ON
DECLARE 
	
	@Minbetv151_31 MONEY,
	@Maxbetv151_31 MONEY,
	@MaxPerMatchv151_31 MONEY,
	@MinBetv151_31_Max MONEY,
	@MaxBetv151_31_Min MONEY,
	@MaxPerMatchv151_31_Min MONEY,
	@MaxPerMatchv151_31_Max MONEY,
	
	
	@Minbetv151_41 MONEY,
	@Maxbetv151_41 MONEY,
	@MaxPerMatchv151_41 MONEY,
	@MinBetv151_41_Max MONEY,
	@MaxBetv151_41_Min MONEY,
	@MaxPerMatchv151_41_Min MONEY,
	@MaxPerMatchv151_41_Max MONEY,
	
	@Minbetv151_51 MONEY,
	@Maxbetv151_51 MONEY,
	@MaxPerMatchv151_51 MONEY,
	@MinBetv151_51_Max MONEY,
	@MaxBetv151_51_Min MONEY,
	@MaxPerMatchv151_51_Min MONEY,
	@MaxPerMatchv151_51_Max MONEY,
	
	@MinBetv152_41 MONEY,
	@Maxbetv152_41 MONEY,
	@MaxPerMatchv152_41 MONEY,
	@MinBetv152_41_Max MONEY,
	@MaxBetv152_41_Min MONEY,
	@MaxPerMatchv152_41_Min MONEY,
	@MaxPerMatchv152_41_Max MONEY,
	
	@MinBetv152_51 MONEY,
	@Maxbetv152_51 MONEY,
	@MaxPerMatchv152_51 MONEY,
	@MinBetv152_51_Max MONEY,
	@MaxBetv152_51_Min MONEY,
	@MaxPerMatchv152_51_Min MONEY,
	@MaxPerMatchv152_51_Max MONEY,
	
	@Minbetv153_51 MONEY,
	@Maxbetv153_51 MONEY,
	@MaxPerMatchv153_51 MONEY,
	@MinBetv153_51_Max MONEY,
	@MaxBetv153_51_Min MONEY,
	@MaxPerMatchv153_51_Min MONEY,
	@MaxPerMatchv153_51_Max MONEY
	

	--v151
	--HR bet setting--
	SELECT
		@Minbetv151_31 = MAX(CASE WHEN cs3.bettype = 31 AND cs3.sporttype = 151 THEN cs3.minbet ELSE 0 END), 
		@Maxbetv151_31 = MAX(CASE WHEN cs3.bettype = 31 AND cs3.sporttype = 151 THEN cs3.maxbet ELSE 0 END), 
		@Minbetv151_41 = MAX(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 151 THEN cs3.minbet ELSE 0 END), 
		@Maxbetv151_41 = MAX(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 151 THEN cs3.maxbet ELSE 0 END), 
		@Minbetv151_51 = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 151 THEN cs3.minbet ELSE 0 END), 
		@Maxbetv151_51 = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 151 THEN cs3.maxbet ELSE 0 END), 
		@MinBetv152_41 = MAX(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 152 THEN cs3.minbet ELSE 0 END), 
		@Maxbetv152_41 = MAX(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 152 THEN cs3.maxbet ELSE 0 END), 
		@MinBetv152_51 = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 152 THEN cs3.minbet ELSE 0 END), 
		@Maxbetv152_51 = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 152 THEN cs3.maxbet ELSE 0 END), 
		@Minbetv153_51 = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 153 THEN cs3.minbet ELSE 0 END), 
		@Maxbetv153_51 = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 153 THEN cs3.maxbet ELSE 0 END)
	FROM Dep_CustSetting3rd as cs3 with (NOLOCK)
	WHERE 
		cs3.custid = @custId AND cs3.sporttype BETWEEN 151 AND 153

	SELECT	@MaxPerMatchv151_31 = maxpermatch151,
			@MaxPerMatchv151_41 = maxpermatch151_OT,
			@MaxPerMatchv151_51 = maxpermatch151_AU,
			@MaxPerMatchv152_41 = maxpermatch152_UK,
			@MaxPerMatchv152_51 = maxpermatch152_AU,
			@MaxPerMatchv153_51 = maxpermatch153_AU
	FROM custinfo WITH(NOLOCK)
	WHERE custid = @custId


	SELECT  
		@MinBetv151_31_Max = MAX(CASE WHEN cs3.bettype = 31 AND cs3.sporttype = 151 THEN MinBet ELSE NULL END),   
		@MaxBetv151_31_Min = MIN(CASE WHEN cs3.bettype = 31 AND cs3.sporttype = 151 THEN CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END ELSE NULL END),	
		@MinBetv151_41_Max = MAX(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 151 THEN MinBet ELSE NULL END),  
		@MaxBetv151_41_Min = MIN(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 151 THEN CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END  ELSE NULL END),	
		@MinBetv151_51_Max = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 151 THEN MinBet ELSE NULL END),  
		@MaxBetv151_51_Min = MIN(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 151 THEN CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END  ELSE NULL END),	
		@MinBetv152_41_Max = MAX(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 152 THEN MinBet ELSE NULL END),  
		@MaxBetv152_41_Min = MIN(CASE WHEN cs3.bettype = 41 AND cs3.sporttype = 152 THEN CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END  ELSE NULL END),	
		@MinBetv152_51_Max = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 152 THEN MinBet ELSE NULL END),  
		@MaxBetv152_51_Min = MIN(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 152 THEN CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END  ELSE NULL END),	
		@MinBetv153_51_Max = MAX(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 153 THEN MinBet ELSE NULL END),  
		@MaxBetv153_51_Min = MIN(CASE WHEN cs3.bettype = 51 AND cs3.sporttype = 153 THEN CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END  ELSE NULL END)	
	FROM Dep_CustSetting3rd as cs3 WITH (NOLOCK)  
		INNER JOIN custinfo as ci WITH (NOLOCK) ON 
			(cs3.CustID = ci.Recommend or cs3.CustID = ci.MRecommend or cs3.CustID = ci.SRecommend) 			
	WHERE ci.custid = @CustID  AND cs3.sporttype BETWEEN 151 AND 153
	

	SELECT 		
		@MaxPerMatchv151_31_Min = 0,
		@MaxPerMatchv151_31_Max = MIN(CASE WHEN cs.MaxPerMatch151    = 0 THEN NULL ELSE cs.MaxPerMatch151    END),
		@MaxPerMatchv151_41_Min = 0,
		@MaxPerMatchv151_41_Max = MIN(CASE WHEN cs.MaxPerMatch151_OT = 0 THEN NULL ELSE cs.MaxPerMatch151_OT END),
		@MaxPerMatchv151_51_Min = 0,
		@MaxPerMatchv151_51_Max = MIN(CASE WHEN cs.MaxPerMatch151_AU = 0 THEN NULL ELSE cs.MaxPerMatch151_AU END),
		@MaxPerMatchv152_41_Min = 0,
		@MaxPerMatchv152_41_Max = MIN(CASE WHEN cs.MaxPerMatch152_UK = 0 THEN NULL ELSE cs.MaxPerMatch152_UK END),
		@MaxPerMatchv152_51_Min = 0,
		@MaxPerMatchv152_51_Max = MIN(CASE WHEN cs.MaxPerMatch152_AU = 0 THEN NULL ELSE cs.MaxPerMatch152_AU END),
		@MaxPerMatchv153_51_Min = 0,
		@MaxPerMatchv153_51_Max = MIN(CASE WHEN cs.MaxPerMatch153_AU = 0 THEN NULL ELSE cs.MaxPerMatch153_AU END)
	FROM custinfo as cs WITH (NOLOCK)  
		INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	WHERE ci.custid = @CustID
	--END--
	
	
	


	--customer info
	SELECT 
		c.username,
		c.currency,	
		--v151
		ISNULL(@minbetv151_31,0)			AS minbetv151_31, 
		ISNULL(@maxbetv151_31,0)			AS maxbetv151_31, 
		ISNULL(@maxpermatchv151_31,0)		AS maxpermatchv151_31,
		ISNULL(@MinBetv151_31_Max,0)		AS MinBetv151_31_Max,
		ISNULL(@MaxBetv151_31_Min,0)		AS MaxBetv151_31_Min,
		ISNULL(@MaxPerMatchv151_31_Min,0)	AS MaxperMatchv151_31_Min,
		ISNULL(@MaxPerMatchv151_31_Max,0)	AS MaxperMatchv151_31_Max,
		ISNULL(@minbetv151_41,0)			AS minbetv151_41, 
		ISNULL(@maxbetv151_41,0)			AS maxbetv151_41, 
		ISNULL(@maxpermatchv151_41,0)		AS maxpermatchv151_41,
		ISNULL(@MinBetv151_41_Max,0)		AS MinBetv151_41_Max,
		ISNULL(@MaxBetv151_41_Min,0)		AS MaxBetv151_41_Min,
		ISNULL(@MaxPerMatchv151_41_Min,0)	AS MaxperMatchv151_41_Min,
		ISNULL(@MaxPerMatchv151_41_Max,0)	AS MaxperMatchv151_41_Max,
		ISNULL(@minbetv151_51,0)			AS minbetv151_51, 
		ISNULL(@maxbetv151_51,0)			AS maxbetv151_51, 
		ISNULL(@maxpermatchv151_51,0)		AS maxpermatchv151_51,
		ISNULL(@MinBetv151_51_Max,0)		AS MinBetv151_51_Max,
		ISNULL(@MaxBetv151_51_Min,0)		AS MaxBetv151_51_Min,
		ISNULL(@MaxPerMatchv151_51_Min,0)	AS MaxperMatchv151_51_Min,
		ISNULL(@MaxPerMatchv151_51_Max,0)	AS MaxperMatchv151_51_Max,
		
		--v152
		ISNULL(@minbetv152_41,0)			AS minbetv152_41, 
		ISNULL(@maxbetv152_41,0)			AS maxbetv152_41, 
		ISNULL(@maxpermatchv152_41,0)		AS maxpermatchv152_41,
		ISNULL(@MinBetv152_41_Max,0)		AS MinBetv152_41_Max,
		ISNULL(@MaxBetv152_41_Min,0)		AS MaxBetv152_41_Min,
		ISNULL(@MaxPerMatchv152_41_Min,0)	AS MaxperMatchv152_41_Min,
		ISNULL(@MaxPerMatchv152_41_Max,0)	AS MaxperMatchv152_41_Max,
		ISNULL(@minbetv152_51,0)			AS minbetv152_51, 
		ISNULL(@maxbetv152_51,0)			AS maxbetv152_51, 
		ISNULL(@maxpermatchv152_51,0)		AS maxpermatchv152_51,
		ISNULL(@MinBetv152_51_Max,0)		AS MinBetv152_51_Max,
		ISNULL(@MaxBetv152_51_Min,0)		AS MaxBetv152_51_Min,
		ISNULL(@MaxPerMatchv152_51_Min,0)	AS MaxperMatchv152_51_Min,
		ISNULL(@MaxPerMatchv152_51_Max,0)	AS MaxperMatchv152_51_Max,
		
		--v153
		ISNULL(@minbetv153_51,0)			AS minbetv153_51, 
		ISNULL(@maxbetv153_51,0)			AS maxbetv153_51, 
		ISNULL(@maxpermatchv153_51,0)		AS maxpermatchv153_51,
		ISNULL(@MinBetv153_51_Max,0)		AS MinBetv153_51_Max,
		ISNULL(@MaxBetv153_51_Min,0)		AS MaxBetv153_51_Min,
		ISNULL(@MaxPerMatchv153_51_Min,0)	AS MaxperMatchv153_51_Min,
		ISNULL(@MaxPerMatchv153_51_Max,0)	AS MaxperMatchv153_51_Max
		
		
	FROM customer c WITH (NOLOCK)
	WHERE c.custid = @custid
	
	
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelEditRB] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelEditRB] TO [vnteam]

