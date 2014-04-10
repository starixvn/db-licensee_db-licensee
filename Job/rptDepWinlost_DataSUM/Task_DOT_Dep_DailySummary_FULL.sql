USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DOT_Dep_DailySummary_FULL]    Script Date: 04/09/2014 20:18:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DOT_Dep_DailySummary_FULL]
	@winlostdate datetime
AS

/*	
	Task : Summary data for deposit member
	DB: DB06.bodb02
	Date: 
		             
	Param's Explanation:
	• @winlostdate: The date need to summary
	
	Revisions:	
		- 20110810@DAniel: Add summary TST data
		- 20110907@Viet: skip this SP during movebet and balance up 
		- 20110901@DAniel: Add summary BA data
*/


if (@winlostdate > current_timestamp) OR EXISTS(SELECT 1 FROM SystemSettings WITH (NOLOCK) WHERE VValue = '1' AND VName in ('isMovingBet','isArchivingBet'))
BEGIN	
	return
END

IF EXISTS(SELECT TOP 1 1 FROM bettrans with (nolock) WHERE winlostdate = @winlostdate AND bettype < 19999)
BEGIN
	print '*** bettrans - ' + convert(varchar(10), @winlostdate, 111) + ' ***'
	EXEC [dbo].[Task_DOT_dep_DailySummary_Bettrans] @winlostdate

	--Summary data for data for TST standards - Daniel@20110810
	EXEC [dbo].[Task_DOT_dep_DailySummary_TST_NEW] @winlostdate

	--Summary data for data for BA - Daniel@20110901
	--EXEC [dbo].[Task_DOT_dep_DailySummaryBA] @winlostdate

END
ELSE
BEGIN
	print '*** bettrans14 - ' + convert(varchar(10), @winlostdate, 111) + ' ***'
	IF EXISTS(SELECT TOP 1 1 FROM bettrans14 with (nolock) WHERE winlostdate = @winlostdate)
	BEGIN
		EXEC [dbo].[Task_DOT_dep_DailySummary_Bettrans14] @winlostdate

		--Summary data for data for TST standards - Daniel@20110810
		EXEC [dbo].[Task_DOT_dep_DailySummary_TST_NEW] @winlostdate

		--Summary data for data for BA - Daniel@20110901
		--EXEC [dbo].[Task_DOT_dep_DailySummaryBA14] @winlostdate
	END
END

