create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	,@ErrorMessage varchar(max)

	-- Проверка на корректность загрузки
	if not exists (
		select 1
		from syn.ImportFile as imf
		where imf.ID = @ID_Record
			and imf.FlagLoaded = cast(1 as bit)
	)
	begin
		set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'
		raiserror(@ErrorMessage, 3, 1)

		return
	end

	CREATE TABLE #ProcessedRows (
		ActionType varchar(255),
		ID int
	)
	
	--Чтение из слоя временных данных
	select
		c.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(sa.DateBegin as date) as DateBegin
		,cast(sa.DateEnd as date) as DateEnd
		,c_distr.ID as ID_dbo_CustomerDistributor
		,cast(isnull(sa.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	from syn.SA_CustomerSeasonal as cs
		join dbo.Customer as c on c.UID_DS = sa.UID_DS_Customer
			and c.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = sa.Season
		join dbo.Customer as c_distr on c_distr.UID_DS = sa.UID_DS_CustomerDistributor
			and c_distr.ID_mapping_DataSource = 1
		join syn.CustomerSystemType as cst on sa.CustomerSystemType = cst.Name
	where try_cast(sa.DateBegin as date) is not null
		and try_cast(sa.DateEnd as date) is not null
		and try_cast(isnull(sa.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		sa.*
		,case
			when c.ID is null 
				then 'UID клиента отсутствует в справочнике "Клиент"'
			when c_distr.ID is null 
				then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null 
				then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null 
				then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(sa.DateBegin as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(sa.DateEnd as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(isnull(sa.FlagActive, 0) as bit) is null 
				then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
		left join dbo.Customer as c on c.UID_DS = sa.UID_DS_Customer
			and c.ID_mapping_DataSource = 1
		left join dbo.Customer as c_distr on c_distr.UID_DS = sa.UID_DS_CustomerDistributor 
			and c_distr.ID_mapping_DataSource = 1
		left join dbo.Season as s on s.Name = sa.Season
		left join syn.CustomerSystemType as cst on cst.Name = sa.CustomerSystemType
	where c.ID is null
		or c_distr.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(sa.DateBegin as date) is null
		or try_cast(sa.DateEnd as date) is null
		or try_cast(isnull(sa.FlagActive, 0) as bit) is null		
end