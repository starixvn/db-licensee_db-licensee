USE bodb_licensee
GO

/*
	Created: 20170912@Harper
	Support: #83058: SSSSEA  - Launch new licensee

	Licensee Name: SSSSEA    
	Licensee Type: ONEworks licensee
	Launch product:
		SB: 15%
			Min Fee: 5000 EUR
			Waive: 3 months.
		VS: 15%
		NG: 15%
		BA				
		
	Launch date: 09-Sep-17
	
	Enable on:
		NAP
		LA
		LRF
		KPI
		OWA
*/

DECLARE @MaxDepositNo INT = 0

SELECT @MaxDepositNo = MAX(OrderNo) + 1
FROM KPI_Groups g WITH (NOLOCK) 
	INNER join KPI_BranchGroup bg WITH (NOLOCK) ON g.GroupID = bg.GroupID
WHERE BranchID = 3

--Deposit Branch
exec KPI_AddNewGroup @GroupName = 'SSSSEA',
					 @BranchID = 3,
					 @OrderNo = @MaxDepositNo,
					 @IsActive = 1,
					 @ProductID = 0