import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { StoreService } from './store.service';
import type {
  GrantBetaCreditPayload,
  PurchaseStoreItemPayload,
  SetStoreLoadoutPayload,
  StoreItemsQuery,
} from './store.types';

interface AuthenticatedUser {
  id: string;
}

@Controller('store')
@UseGuards(SupabaseAuthGuard)
export class StoreController {
  constructor(private readonly storeService: StoreService) {}

  @Get('items')
  listItems(
    @GetUser() user: AuthenticatedUser,
    @Query() query: StoreItemsQuery,
  ) {
    return this.storeService.listItems(user.id, query);
  }

  @Post('purchases')
  purchase(
    @GetUser() user: AuthenticatedUser,
    @Body() payload: PurchaseStoreItemPayload,
  ) {
    return this.storeService.purchase(user.id, payload);
  }

  @Patch('loadout')
  setLoadout(
    @GetUser() user: AuthenticatedUser,
    @Body() payload: SetStoreLoadoutPayload,
  ) {
    return this.storeService.setLoadout(user.id, payload);
  }

  @Post('beta-credits')
  grantBetaCredit(
    @GetUser() user: AuthenticatedUser,
    @Body() payload: GrantBetaCreditPayload,
  ) {
    return this.storeService.grantBetaCredit(user.id, payload);
  }
}
